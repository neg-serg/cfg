import proxypilot_recover


def test_load_provider_roster_keeps_gopass_and_dummy_entries(tmp_path):
    roster = tmp_path / "free_providers.yaml"
    roster.write_text(
        """
providers:
  - name: "groq"
    base_url: "https://api.groq.com/openai/v1"
    gopass_key: "api/groq"
    models:
      - name: "llama-3.3-70b-versatile"
        alias: "fallback-large"
  - name: "ollama"
    base_url: "http://localhost:11434/v1"
    dummy_key: "ollama"
    models:
      - name: "qwen3.5:27b"
        alias: "fallback-large"
""".strip()
    )

    providers = proxypilot_recover.load_provider_roster(roster)

    assert providers == [
        {
            "name": "groq",
            "base_url": "https://api.groq.com/openai/v1",
            "gopass_key": "api/groq",
            "dummy_key": "",
            "models": [{"name": "llama-3.3-70b-versatile", "alias": "fallback-large"}],
        },
        {
            "name": "ollama",
            "base_url": "http://localhost:11434/v1",
            "gopass_key": "",
            "dummy_key": "ollama",
            "models": [{"name": "qwen3.5:27b", "alias": "fallback-large"}],
        },
    ]


def test_build_provider_entries_skips_missing_gopass_keys():
    providers = [
        {
            "name": "groq",
            "base_url": "https://api.groq.com/openai/v1",
            "gopass_key": "api/groq",
            "dummy_key": "",
            "models": [{"name": "llama-3.3-70b-versatile", "alias": "fallback-large"}],
        },
        {
            "name": "ollama",
            "base_url": "http://localhost:11434/v1",
            "gopass_key": "",
            "dummy_key": "ollama",
            "models": [{"name": "qwen3.5:27b", "alias": "fallback-large"}],
        },
    ]

    def fake_read_secret(path):
        if path == "api/groq":
            return "groq-secret"
        raise proxypilot_recover.SecretMissing(path)

    entries = proxypilot_recover.build_provider_entries(providers, fake_read_secret)

    assert entries == [
        {
            "name": "groq",
            "base-url": "https://api.groq.com/openai/v1",
            "api-key": "groq-secret",
            "models": [{"name": "llama-3.3-70b-versatile", "alias": "fallback-large"}],
        },
        {
            "name": "ollama",
            "base-url": "http://localhost:11434/v1",
            "api-key": "ollama",
            "models": [{"name": "qwen3.5:27b", "alias": "fallback-large"}],
        },
    ]


def test_check_mode_reports_present_and_missing_keys(capsys):
    providers = [
        {
            "name": "groq",
            "base_url": "https://api.groq.com/openai/v1",
            "gopass_key": "api/groq",
            "dummy_key": "",
            "models": [],
        },
        {
            "name": "deepseek",
            "base_url": "https://api.deepseek.com/v1",
            "gopass_key": "api/deepseek",
            "dummy_key": "",
            "models": [],
        },
    ]

    def fake_read_secret(path):
        if path == "api/groq":
            return "groq-secret"
        raise proxypilot_recover.SecretMissing(path)

    rc = proxypilot_recover.run_check(providers, fake_read_secret)

    captured = capsys.readouterr()
    assert rc == 1
    assert "groq (api/groq)" in captured.out
    assert "MISSING: deepseek (api/deepseek)" in captured.out


def test_write_openai_compatibility_replaces_existing_block(tmp_path):
    config_path = tmp_path / "config.yaml"
    config_path.write_text(
        """
api-keys:
  - old-key
openai-compatibility:
  - name: "old"
    base-url: "https://old.example"
    api-key-entries:
      - api-key: "old-secret"
    models:
      - name: "old-model"
        alias: "fallback-old"
# ── Payload rules
payload:
  redact: true
""".lstrip()
    )

    entries = [
        {
            "name": "groq",
            "base-url": "https://api.groq.com/openai/v1",
            "api-key": "groq-secret",
            "models": [{"name": "llama-3.3-70b-versatile", "alias": "fallback-large"}],
        }
    ]

    proxypilot_recover.write_openai_compatibility(config_path, entries)

    text = config_path.read_text()
    assert 'name: "groq"' in text
    assert 'api-key: "groq-secret"' in text
    assert 'name: "old"' not in text
    assert "# ── Payload rules" in text
    assert "payload:" in text
