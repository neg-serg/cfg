"""Contract tests for Alertmanager integration."""

import re

import yaml

from tests import REPO_ROOT_PATH

DATA_DIR = REPO_ROOT_PATH / "states" / "data"
STATES_DIR = REPO_ROOT_PATH / "states"
CONFIGS_DIR = STATES_DIR / "configs"


def load_yaml(filename):
    path = DATA_DIR / filename
    with open(path) as fh:
        return yaml.safe_load(fh.read())


def test_alertmanager_in_service_catalog():
    catalog = load_yaml("service_catalog.yaml")
    am = catalog.get("alertmanager")
    assert am is not None, "alertmanager missing from service_catalog.yaml"
    assert am.get("port") == 9093, f"expected port 9093, got {am.get('port')}"
    assert am.get("health_path") == "/-/ready"
    assert am.get("unit") == "alertmanager"
    assert am.get("scope") == "system"
    assert am.get("packages") is None, "alertmanager should not have native packages"
    assert am.get("container_image") == "alertmanager"
    assert am.get("gpu") == "none"


def test_alertmanager_in_container_images():
    images = load_yaml("container_images.yaml")
    am = images.get("alertmanager")
    assert am is not None, "alertmanager missing from container_images.yaml"
    assert am.get("registry") == "docker.io"
    assert am.get("image") == "prom/alertmanager"
    assert am.get("variant") == "v0.28.0"
    digest = am.get("digest")
    assert digest is not None, "alertmanager digest must not be null for remote image"
    assert re.match(r"^sha256:[0-9a-f]{64}$", digest), f"bad digest format: {digest}"


def test_alertmanager_config_has_webhook_receiver():
    src = (CONFIGS_DIR / "alertmanager.yml.j2").read_text()
    assert "receiver: telegram" in src
    assert "webhook_configs" in src
    assert "127.0.0.1:9094" in src


def test_alertmanager_quadlet_exists():
    src = (STATES_DIR / "units" / "alertmanager-container.container").read_text()
    assert "ContainerName=alertmanager" in src
    assert "PublishPort=127.0.0.1:" in src
    assert "--config.file=/etc/alertmanager/alertmanager.yml" in src


def test_monitoring_alertmanager_included_in_system_description():
    src = (STATES_DIR / "system_description.sls").read_text()
    assert "monitoring_alertmanager" in src
    assert "monitoring" in src and "alertmanager" in src


def test_loki_config_references_alertmanager_port():
    src = (CONFIGS_DIR / "loki.yaml.j2").read_text()
    assert "alertmanager_url" in src
    assert "9093" in src


def test_alertmanager_webhook_script_exists():
    src = (STATES_DIR / "scripts" / "alertmanager-webhook").read_text()
    assert "TELEGRAM_TOKEN" in src
    assert "send_telegram" in src
    assert "9094" in src
    assert "WebhookHandler" in src


def test_alertmanager_feature_in_defaults():
    hosts = load_yaml("hosts.yaml")
    defaults = hosts.get("defaults", {})
    mon = defaults.get("features", {}).get("monitoring", {})
    assert "alertmanager" in mon, "alertmanager missing from monitoring defaults"
    assert mon["alertmanager"] is False, "alertmanager should default to false"
