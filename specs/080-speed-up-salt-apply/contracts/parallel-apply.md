# salt_parallel.py — Parallel apply orchestration contract

## Interface

```
salt_parallel.py --groups PARAMS_FILE [--max-parallel N] [--timeout SEC]
```

Where `PARAMS_FILE` is a YAML file containing:
```yaml
groups:
  - name: core
    states: [mounts, cachyos, system_description]
    depends_on: []
  - name: packages
    states: [installers_base, installers_desktop, installers_themes, custom_pkgs]
    depends_on: [core]
  - name: desktop
    states: [audio, fonts, desktop, greetd, pacman_db_warmup]
    depends_on: [packages]
  - name: network
    states: [dns, network, ipv6, amnezia, zapret2, hiddify]
    depends_on: [packages]
  - name: services
    states: [services, monitoring_alerts, user_services, jellyfin, transmission, bitcoind, duckdns, vaultwarden, adguardhome, proxypilot]
    depends_on: [network]
  - name: ai
    states: [ollama, llama_embed, image_generation, video_ai, t5_summarization, telethon_bridge, code_rag, managed_bots]
    depends_on: [services]
```

## Output

JSON to stdout:
```json
{
  "exit_code": 0,
  "phases": [
    {"name": "core", "exit_code": 0, "duration_ms": 1234, "log": "logs/phase-core-20260515-101530.log"},
    {"name": "packages", "exit_code": 0, "duration_ms": 5678, "log": "logs/phase-packages-20260515-101530.log"}
  ],
  "total_duration_ms": 6912,
  "sequential_estimate_ms": 30000
}
```

## Error handling

- If a phase fails (nonzero exit), other in-progress phases receive SIGTERM
- After all phases terminate, aggregated summary is printed with pointers to phase logs
- Exit code = max of all phase exit codes (so any failure propagates)

## salt-apply.sh integration

- `SALT_PARALLEL=1` or `--parallel` flag → call salt_parallel.py instead of single salt-call
- Feature gate: `host.features.apply.parallel` in hosts.yaml
- Auto mode: ignored (single target, no parallelism needed)
