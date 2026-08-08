#!/usr/bin/env bash
# =============================================================================
#  Encrypted DNS for AuchLinux — systemd-resolved + DNS-over-TLS + DNSSEC
#  Replaces plaintext DNS (e.g. an institutional 172.16.x resolver) with
#  authenticated, encrypted lookups. Coexists with Tailscale (which switches to
#  split-DNS via resolved: MagicDNS for the tailnet, DoT for everything else).
#
#  Also installs the nftables firewall (step 7) — DNS + firewall are both part
#  of the same post-install network lockdown.
#
#  Usage:
#     sudo ./scripts/harden-dns-firewall.sh            # apply (DNS + firewall)
#     sudo ./scripts/harden-dns-firewall.sh --revert   # undo DNS (firewall left as-is)
#     sudo ./scripts/harden-dns-firewall.sh --status   # show resolver + firewall state
#
#  Safe to re-run (idempotent). Run after a fresh install (post-install step).
# =============================================================================
set -euo pipefail

RESOLVED_CONF=/etc/systemd/resolved.conf.d/dns-over-tls.conf
NM_CONF=/etc/NetworkManager/conf.d/dns.conf
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Two rulesets: nftables.conf is the base (default-drop inbound).
# nftables.virt-localsend.conf is the same plus the accepts libvirt guests need
# (DHCP/DNS in on virbr0, forward out) and LocalSend's 53317 TCP+UDP. Swap it in
# by hand when you want VMs on the network or file transfers to reach this host;
# stay on the base ruleset on networks you don't trust.
NFT_SRC="$REPO_DIR/config/etc/nftables.conf"

c(){ printf '\033[0;36m[dns]\033[0m %s\n' "$*"; }
ok(){ printf '\033[0;32m[ok]\033[0m  %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m  %s\n' "$*"; }

# Re-exec as root if needed.
[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

case "${1:-apply}" in
  --status)
    resolvectl status 2>/dev/null | grep -E "Current DNS|DNS Servers|DNSOverTLS|DNSSEC|Protocols" || true
    echo "resolv.conf -> $(readlink -f /etc/resolv.conf)"
    echo "firewall    -> nftables: $(systemctl is-enabled nftables 2>/dev/null || true), \
drop-policy chains loaded: $(nft list ruleset 2>/dev/null | grep -c 'policy drop' || true)"
    exit 0 ;;
  --revert)
    c "Reverting to NetworkManager-managed DNS…"
    rm -f "$RESOLVED_CONF" "$NM_CONF"
    systemctl disable --now systemd-resolved 2>/dev/null || true
    # let NetworkManager own resolv.conf again
    rm -f /etc/resolv.conf
    systemctl restart NetworkManager
    systemctl restart tailscaled 2>/dev/null || true
    ok "Reverted. (Re-run without --revert to re-apply.)"
    # Deliberately NOT touching the firewall here: --revert exists mainly for
    # captive portals / broken-DNS sessions, where dropping the firewall too
    # would silently widen exposure. Disable it explicitly if you mean to:
    warn "Firewall left as-is. To disable it: sudo systemctl disable --now nftables"
    exit 0 ;;
esac

# 1. DoT + DNSSEC resolver config (multiple DoT-capable providers + fallback)
c "Writing $RESOLVED_CONF …"
install -d /etc/systemd/resolved.conf.d
cat > "$RESOLVED_CONF" <<'EOF'
[Resolve]
# Preference order: Quad9 -> Cloudflare -> NextDNS. No Google.
# NextDNS here is the generic (unfiltered) anycast endpoint. For YOUR filtered
# NextDNS profile, sign up (free) and replace the hostname with your config id:
#   45.90.28.0#<id>.dns.nextdns.io  45.90.30.0#<id>.dns.nextdns.io
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 45.90.28.0#dns.nextdns.io 45.90.30.0#dns.nextdns.io
# Empty FallbackDNS = disable systemd's built-in fallback (which includes Google).
FallbackDNS=
DNSOverTLS=yes
DNSSEC=allow-downgrade
Cache=yes
EOF

# 2. enable + (re)start the resolver
#    NB: use restart, not `enable --now` — if resolved is already running (e.g. a
#    re-run after editing the config), `--now` won't reload it and you'd keep the
#    OLD servers. restart forces it to read the new config.
c "Enabling + restarting systemd-resolved…"
systemctl enable systemd-resolved
systemctl restart systemd-resolved
resolvectl flush-caches 2>/dev/null || true

# 3. point resolv.conf at the resolved stub (Tailscale then uses the resolved
#    D-Bus API for split-DNS instead of overwriting this file)
c "Linking /etc/resolv.conf -> resolved stub…"
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 4. hand DNS resolution to resolved in NetworkManager
c "Configuring NetworkManager dns=systemd-resolved…"
install -d /etc/NetworkManager/conf.d
cat > "$NM_CONF" <<'EOF'
[main]
dns=systemd-resolved
EOF
systemctl restart NetworkManager

# 5. let Tailscale re-detect resolved (split-DNS mode)
systemctl restart tailscaled 2>/dev/null || true

# 6. verify — retry, because NM + tailscaled restarts take a few seconds to settle
#    (a single immediate query gives false "failed" warnings).
c "Resolver status:"
resolvectl status 2>/dev/null | grep -E "Current DNS|DNS Servers|DNSOverTLS|DNSSEC" || true
ok_query=0
for _ in 1 2 3 4 5 6; do
  if resolvectl query archlinux.org >/dev/null 2>&1; then ok_query=1; break; fi
  sleep 2
done
if [ "$ok_query" = 1 ]; then
  ok "Encrypted DNS active (DoT + DNSSEC). Test query succeeded."
else
  warn "Test query still failing after ~12s. Likely a captive portal (sign in first) or a"
  warn "network blocking port 853. Temp fix: DNSOverTLS=opportunistic in $RESOLVED_CONF, or run with --revert."
fi
echo
c "Captive-portal tip: strict DoT can stall portal sign-in pages. If a café/hotel"
c "Wi-Fi won't load, run '--revert' for that session (or switch to opportunistic)."

# =============================================================================
# 7. FIREWALL — nftables (default-drop inbound)
# =============================================================================
# Steps performed:
#   a) copy the repo ruleset (config/etc/nftables.conf) to /etc/nftables.conf
#   b) enable nftables.service  -> rules reload automatically on every boot
#   c) restart it               -> rules load into the kernel right now
#   d) verify the drop policy is actually live (nft list ruleset)
#
# What the ruleset allows IN (everything else inbound is dropped):
#   - loopback (with anti-spoofing), replies to connections we started
#   - ICMP ping/diagnostics + the ICMPv6 types IPv6 NEEDS (NDP — without these
#     IPv6 breaks entirely)
#   - DHCP client leases (v4+v6) so new Wi-Fi networks still hand out an IP
#   - the tailscale0 interface (device-to-device mesh)
# Outbound stays fully allowed. Opt-ins for mDNS (Chromecast/printers) and
# Steam Remote Play are commented inside the ruleset — uncomment there, then
# re-run this script (or: cp + systemctl restart nftables).
#
# Rollback:  sudo systemctl disable --now nftables     (back to no firewall)
# Manual:    dns-firewall.md "Firewall" section documents all of this step by step.
echo
if [[ -f "$NFT_SRC" ]]; then
  c "Installing nftables firewall ruleset…"
  install -m 644 "$NFT_SRC" /etc/nftables.conf
  systemctl enable nftables
  systemctl restart nftables
  if nft list ruleset 2>/dev/null | grep -q 'policy drop'; then
    ok "Firewall active: default-drop inbound. Inspect with: sudo nft list ruleset"
  else
    warn "nftables service ran but no drop policy is loaded — check /etc/nftables.conf"
  fi
else
  warn "Ruleset not found at $NFT_SRC — firewall step skipped."
fi
