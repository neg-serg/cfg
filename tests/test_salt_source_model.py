"""Tests for the shared Salt source model discovery slice."""

import importlib.util

from tests import REPO_ROOT_PATH


def _load_salt_source_model():
    module_path = REPO_ROOT_PATH / "scripts" / "salt_source_model.py"
    spec = importlib.util.spec_from_file_location("salt_source_model", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_discover_state_files_classifies_top_level_entrypoints_and_workflow_apply_targets(
    tmp_path, monkeypatch
):
    states_dir = tmp_path / "states"
    states_dir.mkdir()
    (states_dir / "system_description.sls").write_text("include:\n  - desktop.system\n")
    (states_dir / "group").mkdir()
    (states_dir / "group" / "ai.sls").write_text("group-ai:\n  test.nop: []\n")
    (states_dir / "desktop").mkdir()
    (states_dir / "desktop" / "system.sls").write_text("desktop-state:\n  test.nop: []\n")

    monkeypatch.chdir(tmp_path)
    salt_source_model = _load_salt_source_model()

    records = salt_source_model.discover_state_files()
    by_relpath = {record.relpath: record for record in records}

    assert set(by_relpath) == {
        "states/system_description.sls",
        "states/group/ai.sls",
        "states/desktop/system.sls",
    }
    assert by_relpath["states/system_description.sls"].top_level_entrypoint is True
    assert by_relpath["states/system_description.sls"].workflow_apply_target is True
    assert by_relpath["states/system_description.sls"].state_name == "system_description"

    assert by_relpath["states/group/ai.sls"].top_level_entrypoint is False
    assert by_relpath["states/group/ai.sls"].workflow_apply_target is True
    assert by_relpath["states/group/ai.sls"].state_name == "group.ai"

    assert by_relpath["states/desktop/system.sls"].top_level_entrypoint is False
    assert by_relpath["states/desktop/system.sls"].workflow_apply_target is False
    assert by_relpath["states/desktop/system.sls"].state_name == "desktop.system"


def test_discover_state_files_keeps_repo_relative_relpath_for_absolute_states_dir(
    tmp_path, monkeypatch
):
    states_dir = tmp_path / "states"
    states_dir.mkdir()
    (states_dir / "system_description.sls").write_text("include:\n  - desktop.system\n")

    monkeypatch.chdir(tmp_path)
    salt_source_model = _load_salt_source_model()

    records = salt_source_model.discover_state_files(str(states_dir.resolve()))

    assert [record.relpath for record in records] == ["states/system_description.sls"]


def test_enrich_source_metadata_collects_imported_yaml_and_feature_guards(tmp_path, monkeypatch):
    states_dir = tmp_path / "states"
    states_dir.mkdir()
    (states_dir / "desktop.sls").write_text(
        """{%- import_yaml 'data/services.yaml' as services %}
{%- import_yaml "data/users.yaml" as users %}
{%- import_yaml 'data/services.yaml' as services_again %}
{% set svc = host.features.services %}
{% if host.features.desktop %}
desktop-state:
  test.nop: []
{% endif %}
{% if host.features.monitoring.alerts %}
alerts-state:
  test.nop: []
{% endif %}
{% if host.features.get('proxypilot', True) %}
proxypilot-state:
  test.nop: []
{% endif %}
{% if host.features.services.get('jellyfin', false) %}
services-state:
  test.nop: []
{% endif %}
{% if host.features.network.get('zapret2', false) %}
network-state:
  test.nop: []
{% endif %}
"""
    )

    monkeypatch.chdir(tmp_path)
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.discover_state_files()[0]
    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.imported_yaml == ["data/services.yaml", "data/users.yaml"]
    assert enriched.feature_guards == [
        "desktop",
        "monitoring.alerts",
        "network.zapret2",
        "proxypilot",
        "services.jellyfin",
    ]


def test_enrich_source_metadata_ignores_comment_only_feature_mentions():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/opencode.sls",
        state_name="opencode",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text=(REPO_ROOT_PATH / "states" / "opencode.sls").read_text(),
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == []


def test_enrich_source_metadata_ignores_non_conditional_feature_assignments():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set svc = host.features.services %}
{% set desktop = host.features.desktop %}
plain-state:
  test.nop: []
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == []


def test_enrich_source_metadata_collects_alias_based_feature_guards():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set net = host.features.network %}
{% set mon = host.features.monitoring %}
{% set svc = host.features.services %}
{% if net.vm_bridge %}
bridge-state:
  test.nop: []
{% endif %}
{% if mon.loki %}
loki-state:
  test.nop: []
{% endif %}
{% if svc.get('jellyfin', False) %}
jellyfin-state:
  test.nop: []
{% endif %}
{% if host.features.desktop %}
desktop-state:
  test.nop: []
{% endif %}
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == [
        "desktop",
        "monitoring.loki",
        "network.vm_bridge",
        "services.jellyfin",
    ]


def test_enrich_source_metadata_collects_dynamic_alias_get_guards_as_wildcards():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set svc = host.features.services %}
{% set net = host.features.network %}
{% set dns = host.features.dns %}
{% for name in ['jellyfin', 'grafana'] %}
{% if svc.get(name, False) %}
service-state:
  test.nop: []
{% endif %}
{% endfor %}
{% if net.get(name, False) %}
network-state:
  test.nop: []
{% endif %}
{% if dns.get(name, False) %}
dns-state:
  test.nop: []
{% endif %}
{% if svc.get('jellyfin', False) %}
jellyfin-state:
  test.nop: []
{% endif %}
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == [
        "dns.*",
        "network.*",
        "services.*",
        "services.jellyfin",
    ]


def test_enrich_source_metadata_collects_dynamic_alias_get_wildcards_from_macro_args():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set svc = host.features.services %}
{% set net = host.features.network %}
{% set dns = host.features.dns %}
{{ render_service(name, opts, svc.get(name, False), 'complex') }}
{{ render_network(name, net.get(name, False)) }}
{{ render_dns(name, dns.get(name, False), ttl) }}
{{ render_service('jellyfin', opts, svc.get('jellyfin', False), 'simple') }}
{{ render_service(name, opts, svc.enabled, 'complex') }}
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == [
        "dns.*",
        "network.*",
        "services.*",
        "services.jellyfin",
    ]


def test_enrich_source_metadata_collects_dynamic_alias_get_wildcards_from_multiline_macro_args():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set svc = host.features.services %}
{{ render_service(
    name,
    opts,
    svc.get(name, False),
    'complex'
) }}
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == ["services.*"]


def test_enrich_source_metadata_ignores_alias_get_assignments_outside_guards():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set svc = host.features.services %}
{% set enabled = svc.get('jellyfin', False) %}
{% set dynamic_enabled = svc.get(name, False) %}
plain-state:
  test.nop: []
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == []


def test_enrich_source_metadata_ignores_plain_output_alias_get_interpolation():
    salt_source_model = _load_salt_source_model()

    record = salt_source_model.StateFileRecord(
        relpath="states/example.sls",
        state_name="example",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="""{% set svc = host.features.services %}
{{ svc.get(name, False) }}
{{ svc.get('jellyfin', False) }}
{{ render_service(name, opts, svc.get(name, False), 'complex') }}
""",
    )

    enriched = salt_source_model.enrich_source_metadata(record)

    assert enriched.feature_guards == ["services.*"]
