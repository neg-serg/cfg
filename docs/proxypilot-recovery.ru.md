# Recovery ProxyPilot

Используйте этот инструмент, когда `gopass` читается из user session, но в развернутом конфиге ProxyPilot потерялись или устарели записи `openai-compatibility`.

## Режим check

```bash
podman run --rm \
  -v "$PWD:/workspace:ro" \
  -v "$HOME/.config/gopass:/root/.config/gopass:ro" \
  -v "$HOME/.local/share/gopass:/root/.local/share/gopass:ro" \
  -v "$HOME/.config/proxypilot:/target-config:rw" \
  proxypilot-recovery check --roster /workspace/states/data/free_providers.yaml --config /target-config/config.yaml
```

## Режим recover

```bash
podman run --rm \
  -v "$PWD:/workspace:ro" \
  -v "$HOME/.config/gopass:/root/.config/gopass:ro" \
  -v "$HOME/.local/share/gopass:/root/.local/share/gopass:ro" \
  -v "$HOME/.config/proxypilot:/target-config:rw" \
  proxypilot-recovery recover --roster /workspace/states/data/free_providers.yaml --config /target-config/config.yaml
```
