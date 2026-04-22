import importlib.util
from pathlib import Path

from tests import REPO_ROOT_PATH


def _load_salt_contracts():
    module_path = REPO_ROOT_PATH / "scripts" / "salt_contracts.py"
    spec = importlib.util.spec_from_file_location("salt_contracts", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def test_check_service_inventory_contracts_reports_missing_targets(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "service_catalog.yaml",
        """
svc_ok:
  unit: svc-ok
  scope: system
  containerized: true
  container_image: image_ok
svc_bad_image:
  unit: svc-ok
  scope: system
  containerized: true
  container_image: image_missing
svc_bad_unit:
  unit: missing-unit
  scope: system
svc_pkg_service:
  unit: sshd
  scope: system
svc_known_service:
  unit: gpg-agent.socket
  scope: user
""",
    )
    _write(
        tmp_path / "states" / "data" / "container_images.yaml",
        """
image_ok:
  registry: docker.io
  image: example/ok
  digest: sha256:123
""",
    )
    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        """
managed_service_identities:
  svc_ok:
    user: svc
    group: svc
    home: /var/lib/svc
managed_service_paths:
  svc_ok_root:
    service: svc_ok
    path: /var/lib/svc
    type: d
    mode: "0755"
  bad_service_path:
    service: missing_service
    path: /var/lib/missing
    type: d
    mode: "0755"
""",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network:
  ssh_proxy:
    service: sshd
dns: {}
""",
    )
    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files:
  - id: ok_user_unit
    filename: present.service
  - id: missing_user_unit
    filename: missing.service
enable_services:
  - name: gpg-agent.socket
enable_now_timers: []
""",
    )
    _write(tmp_path / "states" / "units" / "svc-ok.service", "[Unit]\nDescription=ok\n")
    _write(tmp_path / "states" / "units" / "user" / "present.service", "[Unit]\nDescription=user\n")

    errors = salt_contracts.check_service_inventory_contracts(tmp_path)

    assert errors == [
        "Service catalog 'svc_bad_image' references missing container image 'image_missing'",
        "Service catalog 'svc_bad_unit' references unknown unit 'missing-unit'",
        "Managed resource path 'bad_service_path' references unknown service 'missing_service'",
        "User service unit 'missing.service' does not exist under states/units/user",
    ]


def test_check_service_inventory_contracts_accepts_known_service_variants(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "service_catalog.yaml",
        """
container_svc:
  unit: container-svc
  scope: system
  containerized: true
  container_image: container_image_ok
native_service:
  unit: tailscaled
  scope: system
user_socket:
  unit: ssh-agent.socket
  scope: user
""",
    )
    _write(
        tmp_path / "states" / "data" / "container_images.yaml",
        """
container_image_ok:
  registry: localhost
  image: test
  digest: null
""",
    )
    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        """
managed_service_identities:
  container_svc:
    user: svc
    group: svc
    home: /var/lib/svc
managed_service_paths:
  container_svc_root:
    service: container_svc
    path: /var/lib/svc
    type: d
    mode: "0755"
""",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network:
  vpn:
    service: tailscaled
dns: {}
""",
    )
    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files:
  - id: user_timer
    filename: existing.timer
enable_services:
  - name: ssh-agent.socket
enable_now_timers:
  - name: existing.timer
""",
    )
    _write(tmp_path / "states" / "units" / "container-svc.service", "[Unit]\nDescription=ok\n")
    _write(tmp_path / "states" / "units" / "user" / "existing.timer", "[Unit]\nDescription=user\n")

    errors = salt_contracts.check_service_inventory_contracts(tmp_path)

    assert errors == []


def test_check_service_inventory_contracts_reports_service_catalog_consistency_errors(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "service_catalog.yaml",
        """
blank_packages:
  unit: blank-packages
  scope: system
  packages: ""
repo_fit_container:
  unit: repo-fit-container
  scope: system
  packages: null
  container_image: image_ok
  bind_mounts:
    - host: /var/lib/repo-fit
      container: /data
      mode: rw
missing_container_semantics:
  unit: missing-container-semantics
  scope: system
  packages: null
  container_image: image_ok
""",
    )
    _write(
        tmp_path / "states" / "data" / "container_images.yaml",
        """
image_ok:
  registry: docker.io
  image: example/ok
  digest: sha256:123
""",
    )
    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        "managed_service_identities: {}\nmanaged_service_paths: {}\n",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network: {}
dns: {}
""",
    )
    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files: []
enable_services: []
enable_now_timers: []
""",
    )
    _write(tmp_path / "states" / "units" / "blank-packages.service", "[Unit]\nDescription=blank\n")
    _write(
        tmp_path / "states" / "units" / "repo-fit-container.service",
        "[Unit]\nDescription=repo fit\n",
    )
    _write(
        tmp_path / "states" / "units" / "missing-container-semantics.service",
        "[Unit]\nDescription=missing semantics\n",
    )

    errors = salt_contracts.check_service_inventory_contracts(tmp_path)

    assert errors == [
        "Service catalog 'blank_packages' has invalid packages value '' "
        "(expected non-empty string or null)",
        "Service catalog 'missing_container_semantics' sets container_image but lacks "
        "repo container-service fields",
    ]


def test_check_service_inventory_contracts_rejects_unknown_services_yaml_service_targets(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "service_catalog.yaml",
        """
known_catalog:
  unit: known-catalog
  scope: system
  packages: known-package
""",
    )
    _write(tmp_path / "states" / "data" / "container_images.yaml", "{}\n")
    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        "managed_service_identities: {}\nmanaged_service_paths: {}\n",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex:
  valid_manual:
    manual_start:
      service: known_catalog
  bad_manual:
    manual_start:
      service: missing-manual
network:
  bad_simple:
    service: missing-simple
dns:
  bad_running:
    ensure_running:
      service: missing-running
""",
    )
    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files: []
enable_services: []
enable_now_timers: []
""",
    )
    _write(tmp_path / "states" / "units" / "known-catalog.service", "[Unit]\nDescription=known\n")

    errors = salt_contracts.check_service_inventory_contracts(tmp_path)

    assert errors == [
        "services.yaml complex.bad_manual manual_start.service references unknown "
        "service 'missing-manual'",
        "services.yaml network.bad_simple service references unknown service 'missing-simple'",
        "services.yaml dns.bad_running ensure_running.service references unknown "
        "service 'missing-running'",
    ]


def test_check_service_catalog_units_accepts_repo_quadlet_unit_resolution():
    salt_contracts = _load_salt_contracts()

    errors = salt_contracts.check_service_catalog_units(REPO_ROOT_PATH)

    assert errors == []


def test_check_service_catalog_units_rejects_containerized_unit_mismatch_despite_quadlet(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "service_catalog.yaml",
        """
container_svc:
  unit: sshd
  scope: system
  containerized: true
  container_image: container_image_ok
  bind_mounts:
    - host: /var/lib/container-svc
      container: /data
      mode: rw
""",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network: {}
dns: {}
""",
    )
    _write(
        tmp_path / "states" / "container_svc.sls",
        """
{{ container_service('container-svc', catalog.container_svc, image_registry,
    quadlet_unit_name='container-svc-container',
) }}
""",
    )
    _write(
        tmp_path / "states" / "units" / "container-svc-container.container",
        "[Container]\nImage=localhost/test\n",
    )

    errors = salt_contracts.check_service_catalog_units(tmp_path)

    assert errors == [
        "Service catalog 'container_svc' unit 'sshd' does not match deployed "
        "container service 'container-svc'"
    ]


def test_check_managed_resource_services_rejects_unrelated_state_stems(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(tmp_path / "states" / "stray_state.sls", "stray_state:\n  test.nop: []\n")
    _write(tmp_path / "states" / "data" / "service_catalog.yaml", "{}\n")
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network: {}
dns: {}
""",
    )
    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        """
managed_service_identities: {}
managed_service_paths:
  stray_path:
    service: stray_state
    path: /var/lib/stray
    type: d
""",
    )

    errors = salt_contracts.check_managed_resource_services(tmp_path)

    assert errors == ["Managed resource path 'stray_path' references unknown service 'stray_state'"]


def test_check_managed_resource_services_rejects_unknown_identity_services(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        """
managed_service_identities:
  stray:
    user: stray
    group: stray
    home: /var/lib/stray
    shell: /usr/sbin/nologin
managed_service_paths: {}
""",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network: {}
dns: {}
""",
    )
    _write(tmp_path / "states" / "data" / "service_catalog.yaml", "{}\n")

    errors = salt_contracts.check_managed_resource_services(tmp_path)

    assert errors == ["Managed resource identity 'stray' references unknown service 'stray'"]


def test_check_managed_resource_services_accepts_real_repo_inventory():
    salt_contracts = _load_salt_contracts()

    errors = salt_contracts.check_managed_resource_services(REPO_ROOT_PATH)

    assert errors == []


def test_check_managed_resource_paths_require_explicit_type_and_mode(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        """
managed_service_identities: {}
managed_service_paths:
  broken_path:
    service: loki
    path: /var/lib/loki/broken
""",
    )

    errors = salt_contracts.check_managed_resources_schema(tmp_path)

    assert errors == [
        "managed_service_paths entry 'broken_path' missing valid type",
        "managed_service_paths entry 'broken_path' missing valid mode",
    ]


def test_check_managed_resources_schema_accepts_real_repo_inventory():
    salt_contracts = _load_salt_contracts()

    errors = salt_contracts.check_managed_resources_schema(REPO_ROOT_PATH)

    assert errors == []


def test_check_user_service_unit_files_requires_units_user_directory(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files:
  - id: system_only_unit
    filename: system-only.service
enable_services: []
enable_now_timers: []
""",
    )
    _write(
        tmp_path / "states" / "units" / "system-only.service",
        "[Unit]\nDescription=system only\n",
    )

    errors = salt_contracts.check_user_service_unit_files(tmp_path)

    assert errors == [
        "User service unit 'system-only.service' does not exist under states/units/user"
    ]


def test_check_user_service_unit_files_accepts_real_repo_inventory():
    salt_contracts = _load_salt_contracts()

    errors = salt_contracts.check_user_service_unit_files(REPO_ROOT_PATH)

    assert errors == []


def test_check_user_services_schema_reports_invalid_entries(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files:
  - bad
  - id: ""
    filename: unit.service
  - id: dup
    filename: first.service
  - id: dup
    filename: second.service
  - id: missing_filename
  - id: bad_features
    filename: feature.service
    features: not-a-list
enable_services:
  - bad
  - name: ""
  - name: good.service
    features:
      - unsupported
enable_now_timers:
  - bad
  - enabled: true
""",
    )

    errors = salt_contracts.check_user_services_schema(tmp_path)

    assert errors == [
        "unit_files entry must be mapping, got str",
        "unit_files entry missing valid id: {'id': '', 'filename': 'unit.service'}",
        "duplicate unit_files id: dup",
        "unit_files entry missing valid filename: {'id': 'missing_filename'}",
        "unit_files entry has invalid features: {'id': 'bad_features', 'filename': "
        "'feature.service', 'features': 'not-a-list'}",
        "enable_services entry must be mapping, got str",
        "enable_services entry missing valid name: {'name': ''}",
        "enable_services entry has invalid features: {'name': 'good.service', "
        "'features': ['unsupported']}",
        "enable_now_timers entry must be mapping, got str",
        "enable_now_timers entry missing valid name: {'enabled': True}",
    ]


def test_check_user_services_schema_reports_unhashable_feature_entries(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files:
  - id: bad_feature_shape
    filename: feature.service
    features:
      - unsupported: true
enable_services: []
enable_now_timers:
  - name: later.timer
    features:
      - unsupported: true
""",
    )

    errors = salt_contracts.check_user_services_schema(tmp_path)

    assert errors == [
        "unit_files entry has invalid features: {'id': 'bad_feature_shape', "
        "'filename': 'feature.service', 'features': [{'unsupported': True}]}",
        "enable_now_timers entry has invalid features: {'name': 'later.timer', "
        "'features': [{'unsupported': True}]}",
    ]


def test_check_user_services_schema_reports_non_list_top_level_groups(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files: null
enable_services: null
enable_now_timers: null
""",
    )

    errors = salt_contracts.check_user_services_schema(tmp_path)

    assert errors == [
        "user_services.yaml unit_files must be a list, got NoneType",
        "user_services.yaml enable_services must be a list, got NoneType",
        "user_services.yaml enable_now_timers must be a list, got NoneType",
    ]


def test_check_user_services_schema_reports_non_mapping_root_document(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
- bad
""",
    )

    errors = salt_contracts.check_user_services_schema(tmp_path)

    assert errors == ["user_services.yaml must be a mapping, got list"]


def test_check_service_inventory_contracts_includes_user_services_schema_errors(tmp_path):
    salt_contracts = _load_salt_contracts()

    _write(tmp_path / "states" / "data" / "service_catalog.yaml", "{}\n")
    _write(tmp_path / "states" / "data" / "container_images.yaml", "{}\n")
    _write(
        tmp_path / "states" / "data" / "managed_resources.yaml",
        "managed_service_identities: {}\nmanaged_service_paths: {}\n",
    )
    _write(
        tmp_path / "states" / "data" / "services.yaml",
        """
simple: {}
complex: {}
network: {}
dns: {}
""",
    )
    _write(
        tmp_path / "states" / "data" / "user_services.yaml",
        """
unit_files:
  - id: dup
    filename: one.service
  - id: dup
    filename: two.service
enable_services: []
enable_now_timers: []
""",
    )

    errors = salt_contracts.check_service_inventory_contracts(tmp_path)

    assert errors == [
        "duplicate unit_files id: dup",
        "User service unit 'one.service' does not exist under states/units/user",
        "User service unit 'two.service' does not exist under states/units/user",
    ]
