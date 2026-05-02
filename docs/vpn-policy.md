# Policy Layer for VPN Split Router

Explicit routing rules: always-direct / always-vpn, with timer-based auto-rollback.

## Concept

The policy layer is a layer of explicit rules that have **highest priority** over probe-based routing:

```
vpn-policy-direct  ← highest priority (always-direct from policy)
vpn-policy-vpn     ← always-vpn from policy
vpn-split-router-managed  ← probe-based (automatic discovery)
default route      ← everything else
```

Stored in `~/.config/vpn-split-router/policy.yaml`.

## Commands

### Managing rules

```bash
# Add a domain to always-direct (always direct, no VPN)
vpn-split-router policy add-direct google.com youtube.com

# Add a domain to always-vpn (always through VPN)
vpn-split-router policy add-vpn netflix.com spotify.com

# Remove a domain from policy (from any section)
vpn-split-router policy remove netflix.com

# View current policy
vpn-split-router policy show
```

### Apply and auto-rollback (safety net)

```bash
# 1. Apply policy to sing-box config
#    → creates backup policy.yaml → policy.yaml.rollback
#    → starts vpn-policy-rollback.timer (5 minutes)
vpn-split-router policy apply

# 2. If everything works — confirm changes
#    → removes backup
#    → stops timer
vpn-split-router policy confirm

# 3. If something broke — rollback
#    → policy.yaml.rollback is copied back
#    → sing-box config is re-synced
vpn-split-router policy rollback
```

**Important**: if `confirm` is not run within 5 minutes, the timer will automatically execute `rollback`.

### Sync

```bash
# Force-apply current policy to sing-box (without backup or timer)
vpn-split-router policy sync
```

## Integration with recheck

During `vpn-split-router recheck`, policy rules are automatically synced into routing (after probe-based rules). No separate `policy sync` is needed.

## How it works

1. `policy add-direct` / `policy add-vpn` — only edit `policy.yaml`, don't touch routing
2. `policy apply` — backs up `policy.yaml` → `policy.yaml.rollback`, starts `systemctl --user start vpn-policy-rollback.timer`, syncs to sing-box
3. `vpn-policy-rollback.timer` — systemd user timer, `OnActiveSec=5min`, starts `vpn-policy-rollback.service`
4. `vpn-policy-rollback.service` — `ExecStart=%h/.local/bin/vpn-split-router policy rollback`
5. `policy confirm` — removes backup and stops timer
6. `policy rollback` — restores `policy.yaml` from backup and syncs

### Rules in sing-box config

In `~/.config/sing-box-tun/config.json`, rules appear with tags:

```json
{
  "tag": "vpn-policy-direct",
  "domain_suffix": ["google.com"],
  "outbound": "direct"
}
```

```json
{
  "tag": "vpn-policy-vpn",
  "domain_suffix": ["netflix.com"],
  "outbound": "vpn"
}
```

## Example full cycle

```bash
# Explicitly set routes
vpn-split-router policy add-direct   google.com youtube.com yandex.ru
vpn-split-router policy add-vpn      netflix.com spotify.com chatgpt.com

# Apply with auto-rollback
vpn-split-router policy apply

# Verify sites open correctly
curl -I https://google.com
curl --socks5 127.0.0.1:10808 -I https://netflix.com

# If everything is fine — confirm
vpn-split-router policy confirm

# If something is wrong — rollback manually
vpn-split-router policy rollback
```

## Typical scenarios

| Scenario | What to do |
|----------|-----------|
| Site works slowly through VPN | `vpn-split-router policy add-direct example.com && vpn-split-router policy apply` |
| Site doesn't open without VPN | `vpn-split-router policy add-vpn example.com && vpn-split-router policy apply` |
| Want to reset all rules | `rm ~/.config/vpn-split-router/policy.yaml && vpn-split-router recheck` |
| Applied and everything broke | Do nothing — auto-rollback in 5 minutes, or `vpn-split-router policy rollback` |

## File structure

- `~/.config/vpn-split-router/policy.yaml` — current rules
- `~/.config/vpn-split-router/policy.yaml.rollback` — backup (after `apply`, before `confirm`)
- `~/.config/systemd/user/vpn-policy-rollback.service` — systemd unit for rollback
- `~/.config/systemd/user/vpn-policy-rollback.timer` — systemd timer, 5 minutes
