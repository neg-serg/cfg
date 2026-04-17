# ProxyPilot Recovery

Use this tool when `gopass` is readable in a user session, but the deployed ProxyPilot config has lost or stale `openai-compatibility` entries.

## Check mode

```bash
podman run --rm \
  -v "$PWD:/workspace:ro" \
  -v "$HOME/.config/gopass:/root/.config/gopass:ro" \
  -v "$HOME/.local/share/gopass:/root/.local/share/gopass:ro" \
  -v "$HOME/.config/proxypilot:/target-config:rw" \
  proxypilot-recovery check --roster /workspace/states/data/free_providers.yaml --config /target-config/config.yaml
```

## Recover mode

```bash
podman run --rm \
  -v "$PWD:/workspace:ro" \
  -v "$HOME/.config/gopass:/root/.config/gopass:ro" \
  -v "$HOME/.local/share/gopass:/root/.local/share/gopass:ro" \
  -v "$HOME/.config/proxypilot:/target-config:rw" \
  proxypilot-recovery recover --roster /workspace/states/data/free_providers.yaml --config /target-config/config.yaml
```
