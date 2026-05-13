#!/usr/bin/env python3
"""Lint Salt state files: Jinja2 syntax, YAML validity, duplicate state IDs,
naming conventions, unused imports, require resolution, dangling includes."""

import collections
import glob
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import host_model  # noqa: E402
import jinja2  # noqa: E402
import jinja2.ext  # noqa: E402
import salt_contracts  # noqa: E402
import yaml  # noqa: E402

# --- Salt-specific Jinja2 tags ---
# Salt adds tags like {% import_yaml %}, {% load_yaml %} etc.
# Register them as no-op extensions so jinja2.parse() doesn't choke.

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class SaltTagExtension(jinja2.ext.Extension):
    """Mock Salt-specific Jinja2 tags so templates render in the test environment.

    Handles {% import_yaml %}, {% load_yaml %}, {% import_json %}, {% load_json %},
    and {% import_text %} by loading the referenced file and binding the result
    as a template variable. This allows macro files to export YAML-imported
    variables via {% from 'file' import var %}.
    """
    tags = {"import_yaml", "load_yaml", "import_json", "load_json", "import_text"}

    def parse(self, parser):
        tag = next(parser.stream)

        # Parse: {% tag 'path' as varname %}  or  {% tag 'path' %} (no 'as')
        path_token = next(parser.stream)
        as_target = None

        if parser.stream.current.test("name") and parser.stream.current.value == "as":
            next(parser.stream)  # consume 'as'
            name_token = next(parser.stream)
            as_target = name_token.value

        # Consume remaining tokens until block_end
        while parser.stream.current.test("block_end") is False:
            next(parser.stream)

        lineno = tag.lineno

        call_node = self.call_method(
            "_load_salt_file",
            args=[
                jinja2.nodes.Const(path_token.value),
                jinja2.nodes.Const(tag.value),
            ],
            lineno=lineno,
        )

        if as_target:
            target = jinja2.nodes.Name(as_target, "store", lineno=lineno)
            return [jinja2.nodes.Assign(target, call_node, lineno=lineno)]
        return [jinja2.nodes.Output([call_node], lineno=lineno)]

    def _load_salt_file(self, path, tag, caller=None):
        full_path = os.path.join("states", path)
        tag_base = tag.split("_")[-1]  # yaml, json, or text
        try:
            with open(full_path) as fh:
                if tag_base in ("yaml", "text"):
                    data = yaml.safe_load(fh.read())
                    return _strip_schema(data) if data is not None else {}
                else:  # json
                    return json.loads(fh.read())
        except (FileNotFoundError, yaml.YAMLError, json.JSONDecodeError):
            return {}


def check_jinja_syntax(files):
    """Check Jinja2 syntax for .sls and .jinja files."""
    env = jinja2.Environment(extensions=["jinja2.ext.do", SaltTagExtension])
    errors = 0
    for f in files:
        try:
            with open(f) as fh:
                env.parse(fh.read())
        except jinja2.TemplateSyntaxError as e:
            print(f"\033[31mJinja: {f}:{e.lineno}: {e.message}\033[0m")
            errors += 1
    return errors


_ERR = "\033[31m"
_WARN = "\033[33m"
_RESET = "\033[0m"


def _strip_schema(data):
    """Remove schema_version from loaded YAML dicts (metadata, not data)."""
    if isinstance(data, dict):
        data.pop("schema_version", None)
    return data


def _resolve_import_yaml(source, states_dir="states"):
    """Pre-scan template source for {% import_yaml %} and load the referenced files.

    Returns a dict of {var_name: loaded_data} to inject into the render context.
    Also scans imported macro files (via {% from %}) for their own import_yaml directives,
    since Jinja2's {% from 'file' import var %} can export those variables.
    """
    yaml_vars = {}
    _scan_import_yaml(yaml_vars, source, states_dir)
    # Recursively scan macro files imported via {% from %}
    for match in re.finditer(
        r"\{%-?\s*from\s+['\"]([^'\"]+)['\"]\s+import\b",
        source,
    ):
        macro_path = os.path.join(states_dir, match.group(1))
        if os.path.isfile(macro_path):
            try:
                with open(macro_path) as fh:
                    macro_source = fh.read()
            except OSError:
                continue
            _scan_import_yaml(yaml_vars, macro_source, states_dir)
    return yaml_vars


def _scan_import_yaml(yaml_vars, source, states_dir):
    """Scan source for {% import_yaml %} and add loaded data to yaml_vars."""
    for match in re.finditer(
        r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+(\w+)",
        source,
    ):
        rel_path, var_name = match.group(1), match.group(2)
        yaml_path = os.path.join(states_dir, rel_path)
        try:
            with open(yaml_path) as fh:
                yaml_vars[var_name] = _strip_schema(yaml.safe_load(fh.read()))
        except (FileNotFoundError, yaml.YAMLError):
            pass


class _MockSalt:
    """Mock salt function namespace — routes to Python modules when available."""

    def __init__(self):
        self._module_cache: dict[str, object] = {}

    def _load_module(self, name: str):
        if name in self._module_cache:
            return self._module_cache[name]
        module_map = {
            "host.feature_default": ("_modules.host_features", "feature_default"),
            "host.feature_enabled": ("_modules.host_features", "feature_enabled"),
            "secrets.get": ("_modules.secrets", "gopass_secret"),
            "secrets.proxypilot_key": ("_modules.secrets", "proxypilot_key"),
            "secrets.tg_secret": ("_modules.secrets", "tg_secret"),
            "config.config_file_edit": ("_modules.cfg", "config_file_edit"),
            "pkg.paru_install": ("_modules.pkg", "paru_install"),
            "pkg.simple_service": ("_modules.pkg", "simple_service"),
            "pkg.pkgbuild_install": ("_modules.pkg", "pkgbuild_install"),
            "pkg.flatpak_install": ("_modules.pkg", "flatpak_install"),
            "container.deploy": ("_modules.container", "deploy"),
            "installer.go_pkg": ("_modules.installer", "go_pkg"),
            "installer.curl_bin": ("_modules.installer", "curl_bin"),
            "installer.cargo_pkg": ("_modules.installer", "cargo_pkg"),
            "installer.pip_pkg": ("_modules.installer", "pip_pkg"),
            "installer.http_file": ("_modules.installer", "http_file"),
            "installer.git_clone_deploy": ("_modules.installer", "git_clone_deploy"),
            "installer.git_clone_build": ("_modules.installer", "git_clone_build"),
            "installer.download_font_zip": ("_modules.installer", "download_font_zip"),
            "installer.github_release_to": ("_modules.installer", "github_release_to"),
            "installer.npm_build_workflow": ("_modules.installer", "npm_build_workflow"),
            "installer.curl_extract_tar": ("_modules.installer", "curl_extract_tar"),
            "installer.curl_extract_zip": ("_modules.installer", "curl_extract_zip"),
            "installer.huggingface_file": ("_modules.installer", "huggingface_file"),
            "installer.firefox_extension": ("_modules.installer", "firefox_extension"),
            "installer.install_catalog": ("_modules.installer", "install_catalog"),
            "installer.download_cached": ("_modules.installer", "download_cached"),
            "installer.ver_stamp": ("_modules.installer", "ver_stamp"),
            "service.ensure_dir": ("_modules.service", "ensure_dir"),
            "service.remove_native_unit": ("_modules.service", "remove_native_unit"),
            "service.remove_native_package": ("_modules.service", "remove_native_package"),
            "service.ensure_running": ("_modules.service", "ensure_running"),
            "service.service_stopped": ("_modules.service", "service_stopped"),
            "service.unit_override": ("_modules.service", "unit_override"),
            "service.udev_rule": ("_modules.service", "udev_rule"),
            "service.service_with_unit": ("_modules.service", "service_with_unit"),
            "service.service_with_healthcheck": ("_modules.service", "service_with_healthcheck"),
            "service.managed_sysusers_line": ("_modules.service", "managed_sysusers_line"),
            "service.managed_tmpfiles_line": ("_modules.service", "managed_tmpfiles_line"),
            "service.managed_identity_guard": ("_modules.service", "managed_identity_guard"),
            "service.managed_path_guard": ("_modules.service", "managed_path_guard"),
            "service.env_block": ("_modules.service", "env_block"),
            "service.managed_resource_value": ("_modules.service", "managed_resource_value"),
            "service.managed_mode_value": ("_modules.service", "managed_mode_value"),
            "service.render_service_yaml": ("_modules.service", "render_service_yaml"),
            "service.ipv6_tunnel": ("_modules.service", "ipv6_tunnel"),
            "common.get_host": ("_modules.common", "get_host"),
            "common.get_constants": ("_modules.common", "get_constants"),
            "user_service.user_service_file": ("_modules.user_service", "user_service_file"),
            "user_service.user_unit_override": ("_modules.user_service", "user_unit_override"),
            "user_service.user_service_enable": ("_modules.user_service", "user_service_enable"),
            "user_service.user_service_with_unit": ("_modules.user_service", "user_service_with_unit"),
            "user_service.user_service_restart": ("_modules.user_service", "user_service_restart"),
            "user_service.user_service_disable": ("_modules.user_service", "user_service_disable"),
            "user_service.user_linger": ("_modules.user_service", "user_linger"),
            "desktop.browser_extensions": ("_modules.desktop", "browser_extensions"),
            "desktop.hyprpm_update": ("_modules.desktop", "hyprpm_update"),
            "desktop.hyprpm_add": ("_modules.desktop", "hyprpm_add"),
            "desktop.hyprpm_enable": ("_modules.desktop", "hyprpm_enable"),
            "desktop.dconf_settings": ("_modules.desktop", "dconf_settings"),
        }
        if name in module_map:
            mod_name, func_name = module_map[name]
            try:
                mod_path = os.path.join(REPO_ROOT, "states", mod_name.replace(".", os.sep) + ".py")
                spec = importlib.util.spec_from_file_location(mod_name, mod_path)
                if spec and spec.loader:
                    _mods_parent = os.path.join(REPO_ROOT, "states")
                    sys.path.insert(0, _mods_parent)
                    try:
                        mod = importlib.util.module_from_spec(spec)
                        spec.loader.exec_module(mod)
                        func = getattr(mod, func_name, None)
                        if func:
                            self._module_cache[name] = func
                            return func
                    finally:
                        if _mods_parent in sys.path:
                            sys.path.remove(_mods_parent)
            except Exception:
                pass
        return None

    def __getitem__(self, key):
        if key == "slsutil.merge":
            return self._merge
        if key == "cmd.run_all":
            return lambda *a, **kw: {"retcode": 1, "stdout": ""}
        if key == "cmd.run_stdout":
            return lambda *a, **kw: ""

        # Try Python module routing
        func = self._load_module(key)
        if func is not None:
            return func

        return lambda *a, **kw: ""

    @staticmethod
    def _merge(base, override, strategy="recurse"):
        if strategy == "recurse":
            merged = host_model.recursive_merge(base, override)
        else:
            merged = base.copy()
            merged.update(override)
        return host_model.enable_all_features(merged)


def _make_render_env():
    """Create a Jinja2 environment with mock salt/grains for full template rendering."""
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader("states"),
        extensions=["jinja2.ext.do", SaltTagExtension],
        undefined=jinja2.Undefined,
    )
    host = host_model.build_lint_host()
    env.globals["grains"] = {"host": "lint-check"}
    env.globals["salt"] = _MockSalt()
    # Macros in _macros_pkg/_macros_service access these directly (not via import)
    env.globals["host"] = host
    # Salt-specific filters
    def _yaml_dquote(value):
        return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'
    env.filters["yaml_dquote"] = _yaml_dquote
    return env


def check_duplicate_state_ids(sls_files):
    """Render .sls files with mock context and check for duplicate state IDs.

    Returns (errors, render_ok, all_ids, rendered_docs) where rendered_docs
    maps filepath → list of parsed YAML documents (for requisite checking).
    """
    env = _make_render_env()
    all_ids = []
    rendered_docs = {}
    render_ok = 0
    for path in sls_files:
        name = path.removeprefix("states/")
        try:
            t = env.get_template(name)
            # Pre-load any {% import_yaml %} data so templates render correctly
            with open(path) as fh:
                yaml_vars = _resolve_import_yaml(fh.read())
            rendered = t.render(**yaml_vars)
            docs = []
            for doc in yaml.safe_load_all(rendered):
                if doc and isinstance(doc, dict):
                    for key in doc:
                        if key not in _SALT_DIRECTIVES:
                            all_ids.append(key)
                    docs.append(doc)
            rendered_docs[path] = docs
            render_ok += 1
        except Exception:
            # Files using Salt-only features won't render
            pass

    dupes = [k for k, v in collections.Counter(all_ids).items() if v > 1]
    errors = 0
    for d in dupes:
        print(f"\033[31mDuplicate state ID: {d}\033[0m")
        errors += 1
    return errors, render_ok, all_ids, rendered_docs


_RESERVED_PREFIXES = ("install_", "build_")
_RAW_STATE_ID_RE = re.compile(r"^([A-Za-z_][\w.-]*)\s*:")


def check_state_id_naming(sls_files, rendered_ids):
    """Check state ID naming conventions.

    Rules:
    - IDs must not contain '/' (file paths should use name: parameter)
    - Reserved prefixes (install_*, build_*) in raw .sls source should only
      come from macros, not appear as hand-written state IDs
    """
    errors = 0

    # Check rendered IDs for file-path-like patterns (3+ segments, e.g. /etc/foo/bar)
    # Shallow paths like /mnt/zero are OK (common for mount state IDs).
    # Font directory paths from download_font_zip macro are also expected.
    seen = set()
    for sid in rendered_ids:
        if sid.count("/") >= 3 and sid not in seen:
            if "/.local/share/fonts/" in sid:
                continue
            seen.add(sid)
            print(
                f"\033[31mNaming: '{sid}'"
                f" — use descriptive name + name: parameter, not file path\033[0m"
            )
            errors += 1

    # Check raw .sls for inline use of reserved prefixes
    for path in sls_files:
        with open(path) as fh:
            for lineno, line in enumerate(fh, 1):
                m = _RAW_STATE_ID_RE.match(line)
                if m:
                    sid = m.group(1)
                    if any(sid.startswith(p) for p in _RESERVED_PREFIXES):
                        print(
                            f"\033[33mNaming: {path}:{lineno}: '{sid}'"
                            f" — install_*/build_* prefix reserved for macros\033[0m"
                        )
                        errors += 1

    return errors


def check_yaml_configs(config_files):
    """Validate YAML syntax in config files."""
    errors = 0
    for f in config_files:
        try:
            with open(f) as fh:
                yaml.safe_load(fh.read())
        except yaml.YAMLError as e:
            print(f"\033[31mYAML: {f}: {e}\033[0m")
            errors += 1
    return errors


# --- Cross-file validation checks ---

_IMPORT_FROM_RE = re.compile(r"\{%-?\s*from\s+['\"]([^'\"]+)['\"]\s+import\s+(.+?)\s*-?%\}")
_IMPORT_YAML_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+(\w+)\s*-?%\}")
_REQUISITE_KEYS = frozenset(
    {
        "require",
        "watch",
        "onchanges",
        "onfail",
        "prereq",
        "require_in",
        "watch_in",
        "onchanges_in",
        "onfail_in",
    }
)
# Salt directives that are top-level YAML keys but not state IDs
_SALT_DIRECTIVES = frozenset({"include", "extend"})


def check_unused_imports(sls_files):
    """Detect imported but unused macros/variables in .sls files."""
    warnings = 0
    for path in sls_files:
        with open(path) as fh:
            source = fh.read()

        # Collect all imports: (source_file, local_name)
        imports = []
        for m in _IMPORT_FROM_RE.finditer(source):
            src_file = m.group(1)
            for item in m.group(2).split(","):
                item = item.strip()
                if " as " in item:
                    _, alias = item.split(" as ", 1)
                    imports.append((src_file, alias.strip()))
                else:
                    imports.append((src_file, item.strip()))

        for m in _IMPORT_YAML_RE.finditer(source):
            imports.append((m.group(1), m.group(2)))

        if not imports:
            continue

        # Remove import lines from source to get the body
        body = _IMPORT_FROM_RE.sub("", source)
        body = _IMPORT_YAML_RE.sub("", body)

        for src_file, name in imports:
            if not re.search(r"\b" + re.escape(name) + r"\b", body):
                print(f"\033[33mUnused import: {path}: '{name}' from '{src_file}'\033[0m")
                warnings += 1

    return warnings


def check_require_resolve(rendered_docs, global_ids, suppressions=None):
    """Validate that all requisite references point to existing state IDs."""
    valid_ids = set(global_ids)
    errors = 0
    suppressions = suppressions or {}

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES:
                    continue
                if not isinstance(state_body, dict):
                    continue
                # Check if require-resolve is suppressed for this state
                state_suppressions = suppressions.get(state_id, set())
                if "require-resolve" in state_suppressions:
                    continue
                for mod_func, directives in state_body.items():
                    if not isinstance(directives, list):
                        continue
                    for directive in directives:
                        if not isinstance(directive, dict):
                            continue
                        for req_key in _REQUISITE_KEYS:
                            if req_key not in directive:
                                continue
                            req_list = directive[req_key]
                            if not isinstance(req_list, list):
                                continue
                            for item in req_list:
                                if not isinstance(item, dict):
                                    continue
                                for req_type, req_id in item.items():
                                    req_id = str(req_id)
                                    if req_id not in valid_ids:
                                        print(
                                            f"\033[31mRequire: {filepath}:"
                                            f" {state_id} → {req_type}:"
                                            f" {req_id} (not found)\033[0m"
                                        )
                                        errors += 1

    return errors


def check_dangling_includes(sls_files):
    """Verify that include: list entries point to existing .sls files."""
    errors = 0
    for path in sls_files:
        with open(path) as fh:
            source = fh.read()

        in_include = False
        for line in source.splitlines():
            stripped = line.strip()
            if stripped == "include:":
                in_include = True
                continue
            if not in_include:
                continue
            # Still inside include block
            if stripped.startswith("- "):
                name = stripped[2:].strip()
                # Strip inline comments
                if " #" in name:
                    name = name[: name.index(" #")].strip()
                if "#" in name and name.startswith("#"):
                    continue
                if name:
                    target = f"states/{name.replace('.', '/')}.sls"
                    if not os.path.isfile(target):
                        print(
                            f"\033[31mDangling include: {path}:"
                            f" '{name}' → {target} not found\033[0m"
                        )
                        errors += 1
            elif stripped.startswith("#") or stripped == "":
                continue
            else:
                # Non-list, non-comment line → end of include block
                in_include = False

    return errors


# Patterns indicating the cmd.run command accesses the network
_NETWORK_CMD_RE = re.compile(
    r"""
    \bcurl\s          # curl downloads
    | \bwget\s        # wget downloads
    | \bgit\s+clone\b # git clone
    | \bgit\s+pull\b  # git pull
    | \bpacman\s+-S\b # pacman install (not -Q queries)
    | \bparu\s        # AUR helper (always downloads)
    | \bmakepkg\b     # builds from AUR (downloads sources)
    | \bcargo\s+install\b
    | \bpip\s+install\b
    | \bnpm\s+install\b
    """,
    re.VERBOSE,
)
# Curl to localhost/127.0.0.1 is a health check, not a network download
_LOCALHOST_CURL_RE = re.compile(r"\bcurl\s.*\b(127\.0\.0\.1|localhost)\b")


def check_network_resilience(rendered_docs):
    """Check that cmd.run states with network commands have retry and parallel.

    Reports warnings (not errors) since some states intentionally omit parallel
    due to require chains or CPU-heavy builds.
    """
    warnings = 0

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES:
                    continue
                if not isinstance(state_body, dict):
                    continue
                for mod_func, directives in state_body.items():
                    if mod_func not in ("cmd.run", "cmd.script"):
                        continue
                    if not isinstance(directives, list):
                        continue

                    cmd_text = ""
                    has_retry = False
                    has_parallel = False
                    has_require = False

                    for d in directives:
                        if not isinstance(d, dict):
                            continue
                        if "name" in d:
                            cmd_text = str(d["name"])
                        if "retry" in d:
                            has_retry = True
                        if "parallel" in d:
                            has_parallel = True
                        if "require" in d:
                            has_require = True

                    if not _NETWORK_CMD_RE.search(cmd_text):
                        continue
                    # Exclude localhost health checks (curl to 127.0.0.1/localhost)
                    if _LOCALHOST_CURL_RE.search(cmd_text) and not re.search(
                        r"\b(wget|git\s+clone|pacman\s+-S|paru|makepkg)\b", cmd_text
                    ):
                        continue

                    if not has_retry:
                        print(
                            f"\033[33mNetwork: {filepath}:"
                            f" '{state_id}' — network command without retry:\033[0m"
                        )
                        warnings += 1
                    if not has_parallel and not has_require:
                        print(
                            f"\033[33mNetwork: {filepath}:"
                            f" '{state_id}' — network command without"
                            f" parallel: True (and no require: chain)\033[0m"
                        )
                        warnings += 1

    return warnings


_SUPPRESSION_RE = re.compile(r"#\s*salt-lint:\s*disable=([a-z_,\s-]+)")

_IDEMPOTENCY_GUARDS = frozenset({"creates", "unless", "onlyif"})
_IDEMPOTENCY_REQUISITE_GUARDS = frozenset({"onchanges", "onchanges_in"})


def _parse_suppressions(sls_files):
    """Parse inline suppression comments from source .sls files.

    Returns a dict: {state_id: set_of_suppressed_rules}.
    Suppression applies to the state block immediately following the comment.
    """
    suppressions = {}
    for path in sls_files:
        with open(path) as fh:
            lines = fh.readlines()

        pending_rules = set()
        for line in lines:
            stripped = line.strip()
            # Check for suppression comment
            m = _SUPPRESSION_RE.search(stripped)
            if m:
                rules = {r.strip() for r in m.group(1).split(",")}
                pending_rules.update(rules)
                continue

            # Check if this is a state ID line (top-level YAML key)
            id_m = _RAW_STATE_ID_RE.match(line)
            if id_m and pending_rules:
                state_id = id_m.group(1)
                suppressions.setdefault(state_id, set()).update(pending_rules)
                pending_rules = set()
            elif stripped and not stripped.startswith("#"):
                # Non-comment, non-empty line that isn't a state ID clears pending
                pending_rules = set()

    return suppressions


def check_idempotency_guards(rendered_docs, suppressions=None):
    """Check that cmd.run/cmd.script states have idempotency guards.

    Every cmd.run/cmd.script state must have at least one of:
    - creates: (file marker)
    - unless: (state check)
    - onlyif: (conditional guard)
    - onchanges: (requisite trigger — the trigger IS the guard)

    States with salt-lint: disable=idempotency are skipped.
    """
    suppressions = suppressions or {}
    warnings = 0

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES:
                    continue
                if not isinstance(state_body, dict):
                    continue

                # Check suppression
                if "idempotency" in suppressions.get(state_id, set()):
                    continue

                for mod_func, directives in state_body.items():
                    if mod_func not in ("cmd.run", "cmd.script"):
                        continue
                    if not isinstance(directives, list):
                        continue

                    has_guard = False
                    for d in directives:
                        if not isinstance(d, dict):
                            continue
                        # Direct guards
                        if any(k in d for k in _IDEMPOTENCY_GUARDS):
                            has_guard = True
                            break
                        # Requisite guards (onchanges means "only run when dependency changed")
                        if any(k in d for k in _IDEMPOTENCY_REQUISITE_GUARDS):
                            has_guard = True
                            break

                    if not has_guard:
                        print(
                            f"\033[33mIdempotency: {filepath}:"
                            f" '{state_id}' — cmd.run/cmd.script without"
                            f" creates/unless/onlyif/onchanges guard\033[0m"
                        )
                        warnings += 1

    return warnings


def check_stale_suppressions(sls_files, rendered_docs, suppressions):
    """Warn when a suppression comment exists but no matching violation would fire.

    This catches suppressions that were added for a violation that has since been
    fixed, preventing dead suppression comments from accumulating.
    """
    warnings = 0

    # Collect state IDs that would have violations (without suppressions)
    idempotency_violators = set()
    network_violators = set()

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES or not isinstance(state_body, dict):
                    continue
                for mod_func, directives in state_body.items():
                    if mod_func not in ("cmd.run", "cmd.script"):
                        continue
                    if not isinstance(directives, list):
                        continue

                    # Check idempotency
                    has_guard = False
                    cmd_text = ""
                    for d in directives:
                        if not isinstance(d, dict):
                            continue
                        if any(k in d for k in _IDEMPOTENCY_GUARDS):
                            has_guard = True
                        if any(k in d for k in _IDEMPOTENCY_REQUISITE_GUARDS):
                            has_guard = True
                        if "name" in d:
                            cmd_text = str(d["name"])
                    if not has_guard:
                        idempotency_violators.add(state_id)

                    # Check network
                    if _NETWORK_CMD_RE.search(cmd_text):
                        if not (
                            _LOCALHOST_CURL_RE.search(cmd_text)
                            and not re.search(
                                r"\b(wget|git\s+clone|pacman\s+-S|paru|makepkg)\b", cmd_text
                            )
                        ):
                            has_retry = any(
                                isinstance(d, dict) and "retry" in d for d in directives
                            )
                            has_parallel = any(
                                isinstance(d, dict) and "parallel" in d for d in directives
                            )
                            if not has_retry or not has_parallel:
                                network_violators.add(state_id)

    # Check each suppression against actual violations
    rule_to_violators = {
        "idempotency": idempotency_violators,
        "network-retry": network_violators,
        "network-parallel": network_violators,
    }

    for state_id, rules in suppressions.items():
        for rule in rules:
            violators = rule_to_violators.get(rule)
            if violators is not None and state_id not in violators:
                print(
                    f"\033[33mStale suppression: '{state_id}'"
                    f" — salt-lint: disable={rule} but no violation exists\033[0m"
                )
                warnings += 1

    return warnings


def check_data_integrity():
    """Validate YAML data files: required keys, version cross-references."""
    errors = 0

    try:
        with open("states/data/versions.yaml") as fh:
            versions = yaml.safe_load(fh) or {}
    except (FileNotFoundError, yaml.YAMLError):
        return 0

    # Required keys by section type
    required_keys = {
        "curl_extract_zip": ["url"],
        "curl_extract_tar": ["url", "binary_pattern"],
        "download_zip": ["url"],
    }

    # Data files with versioned tool definitions
    data_files = [
        "states/data/installers.yaml",
        "states/data/installers_desktop.yaml",
        "states/data/fonts.yaml",
    ]

    for data_file in data_files:
        try:
            with open(data_file) as fh:
                data = yaml.safe_load(fh) or {}
        except (FileNotFoundError, yaml.YAMLError):
            continue

        basename = os.path.basename(data_file)

        for section, entries in data.items():
            if not isinstance(entries, dict):
                continue

            # Check required keys
            if section in required_keys:
                for name, opts in entries.items():
                    if not isinstance(opts, dict):
                        continue
                    for key in required_keys[section]:
                        if key not in opts:
                            print(
                                f"\033[31mData: {basename}:"
                                f" {section}.{name} missing required key"
                                f" '{key}'\033[0m"
                            )
                            errors += 1

            # Check ${VER} references have matching versions.yaml entry
            for name, opts in entries.items():
                url = ""
                if isinstance(opts, str):
                    url = opts
                elif isinstance(opts, dict):
                    url = opts.get("url", "")

                if "${VER}" in url:
                    ver_key = name.replace("-", "_")
                    if ver_key not in versions:
                        print(
                            f"\033[31mData: {basename}:"
                            f" {section}.{name} uses ${{VER}} but"
                            f" '{ver_key}' not in versions.yaml\033[0m"
                        )
                        errors += 1

    return errors


# Bash-specific syntax patterns that require shell: /bin/bash
_BASH_SYNTAX_RE = re.compile(
    r"""
    \bset\s+-[a-z]*o\s+pipefail\b   # set -eo pipefail (pipefail not POSIX)
    | \bdeclare\s+-             # declare -a/-A/-i (bash builtin)
    | \breadarray\b             # readarray/mapfile (bash 4+)
    | \bmapfile\b
    | \[\[                      # [[ ]] extended test (bash/zsh, not POSIX)
    | <<<                       # here-string (bash/zsh, not POSIX)
    | \$\{[^}]+%%              # ${var%%pattern} advanced expansion (works in POSIX
                                # but often combined with other bash-isms)
    """,
    re.VERBOSE,
)


def check_cmd_shell(rendered_docs):
    """Check that multiline cmd.run using bash features specify shell: /bin/bash.

    Salt defaults to /bin/sh, which is bash on Arch but not POSIX-guaranteed.
    States using bash-specific syntax should be explicit.
    """
    warnings = 0

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES:
                    continue
                if not isinstance(state_body, dict):
                    continue
                for mod_func, directives in state_body.items():
                    if mod_func not in ("cmd.run", "cmd.script"):
                        continue
                    if not isinstance(directives, list):
                        continue

                    cmd_text = ""
                    has_shell = False

                    for d in directives:
                        if not isinstance(d, dict):
                            continue
                        if "name" in d:
                            cmd_text = str(d["name"])
                        if "shell" in d:
                            has_shell = True

                    # Only check multiline commands (single-line rarely needs bash)
                    if "\n" not in cmd_text.strip():
                        continue
                    if has_shell:
                        continue
                    if _BASH_SYNTAX_RE.search(cmd_text):
                        print(
                            f"\033[33mShell: {filepath}:"
                            f" '{state_id}' — bash syntax without"
                            f" shell: /bin/bash\033[0m"
                        )
                        warnings += 1

    return warnings


# salt:// paths in string literals (handles both 'salt://...' and "salt://...")
_SALT_URI_RE = re.compile(r"""salt://([^'"\s}]+)""")

# file_roots search order (relative to project root)
def _load_file_roots():
    """Read file_roots from states/file_roots.yaml (single source of truth).

    Returns list of relative paths (e.g. ['states', '.']).
    Falls back to hardcoded defaults if file is missing or unparseable.
    """
    roots_path = os.path.join("states", "file_roots.yaml")
    default = ["states", "."]
    try:
        yaml_path = os.path.join(REPO_ROOT, roots_path)
        with open(yaml_path) as fh:
            data = yaml.safe_load(fh.read())
    except (FileNotFoundError, AttributeError):
        return default
    if not isinstance(data, dict) or not isinstance(data.get("base"), list):
        return default
    paths = data["base"]
    resolved = []
    for p in paths:
        if not isinstance(p, str):
            continue
        p = p.replace("${project_dir}/", "").rstrip("/")
        if not p:
            p = "."
        resolved.append(p)
    return resolved if resolved else default


_FILE_ROOTS = _load_file_roots()


def check_salt_uri_refs(sls_files, jinja_files, data_files=None):
    """Validate that salt:// references point to existing files.

    Checks .sls, .jinja, and data YAML files. Resolves paths using the same
    file_roots order as the Salt minion config (states/, then project root).
    Skips paths containing Jinja expressions ({{ ... }}).
    """
    errors = 0
    seen = set()
    all_files = sls_files + jinja_files + (data_files or [])

    for path in all_files:
        with open(path) as fh:
            in_comment = False
            for lineno, line in enumerate(fh, 1):
                # Track Jinja block comments {# ... #}
                if "{#" in line:
                    in_comment = True
                if "#}" in line:
                    in_comment = False
                    continue
                if in_comment:
                    continue
                # Skip YAML/shell comments
                if line.lstrip().startswith("#"):
                    continue

                for m in _SALT_URI_RE.finditer(line):
                    ref = m.group(1)
                    # Skip paths with unresolved Jinja expressions
                    if "{{" in ref or "{%" in ref or "}}" in ref:
                        continue
                    # Deduplicate (same ref from macro docs, etc.)
                    key = (path, ref)
                    if key in seen:
                        continue
                    seen.add(key)

                    # Check file_roots in order
                    found = any(os.path.exists(os.path.join(root, ref)) for root in _FILE_ROOTS)
                    if not found:
                        print(
                            f"\033[31mSalt URI: {path}:{lineno}:"
                            f" salt://{ref} — file not found\033[0m"
                        )
                        errors += 1

    return errors


# Noise patterns from systemd-analyze verify (not errors in our unit files)
_SYSTEMD_NOISE_RE = re.compile(
    r"""
    is\ not\ executable          # binary not installed yet
    | Cannot\ find\ unit         # dependency resolution
    | not\ found\ in\ search     # unit not installed
    | Unit\ \S+\ not\ found      # newer systemd: dependency not installed
    | Failed\ to\ create.*not\ found  # newer systemd: ordering dep missing
    | has\ a\ bad\ unit\ file    # summary line (details are separate)
    | Support\ for\ option.*removed  # system-level deprecation noise
    """,
    re.VERBOSE,
)


def check_systemd_units():
    """Validate systemd unit files with systemd-analyze verify.

    Checks both plain unit files and rendered .j2 templates.
    Filters noise from dependency resolution and missing binaries.
    """
    if not shutil.which("systemd-analyze"):
        return 0, 0

    plain_units = sorted(
        glob.glob("states/units/**/*.service", recursive=True)
        + glob.glob("states/units/**/*.timer", recursive=True)
        + glob.glob("dotfiles/**/systemd/**/*.service", recursive=True)
        + glob.glob("dotfiles/**/systemd/**/*.timer", recursive=True)
    )
    j2_units = sorted(
        glob.glob("states/units/**/*.service.j2", recursive=True)
        + glob.glob("states/units/**/*.timer.j2", recursive=True)
    )

    errors = 0
    checked = 0

    def _run_verify(filepath, source_path=None):
        """Run systemd-analyze verify and return relevant error lines."""
        result = subprocess.run(
            ["systemd-analyze", "verify", "--man=no", filepath],
            capture_output=True,
            text=True,
        )
        basename = os.path.basename(filepath)
        relevant = []
        for line in result.stderr.splitlines():
            # Only keep lines about OUR unit file
            if basename not in line and filepath not in line:
                continue
            if _SYSTEMD_NOISE_RE.search(line):
                continue
            relevant.append(line)
        return relevant

    # Separate plain units into truly-plain and Jinja-templated
    jinja_re = re.compile(r"\{\{|\{%")
    truly_plain = []
    for path in plain_units:
        with open(path) as f:
            content = f.read()
        if jinja_re.search(content):
            j2_units.append(path)
        else:
            truly_plain.append(path)

    # Plain unit files (no Jinja syntax)
    for path in truly_plain:
        checked += 1
        issues = _run_verify(path)
        if issues:
            label = path
            for line in issues:
                print(f"\033[31mUnit: {label}: {line}\033[0m")
            errors += 1

    # Render Jinja templates (.j2 and plain files with Jinja syntax) and verify
    env = _make_render_env()
    host = host_model.build_lint_host()
    default_home = host.get("home") or os.path.expanduser("~")
    j2_context = {
        "user": host.get("user", "neg"),
        "home": default_home,
        "uid": host.get("uid", 1000),
        "mnt_one": host.get("mnt_one", "/mnt/one"),
        "ollama_port": 11434,
        "dns_unbound": True,
        "gpu_enable": True,
        "project_dir": default_home + "/src/cfg",
    }
    for path in sorted(j2_units):
        try:
            with open(path) as fh:
                source = fh.read()
            t = env.from_string(source)
            rendered = t.render(**j2_context)
        except Exception:
            continue

        # Determine suffix from original filename (.service.j2 → .service)
        suffix = "." + path.removesuffix(".j2").rsplit(".", 1)[-1]
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=suffix, prefix="lint-", delete=False
        ) as f:
            f.write(rendered)
            tmppath = f.name

        try:
            checked += 1
            issues = _run_verify(tmppath, source_path=path)
            if issues:
                for line in issues:
                    # Replace tmpfile path with original source path
                    line = line.replace(tmppath, path).replace(
                        os.path.basename(tmppath), os.path.basename(path)
                    )
                    print(f"\033[31mUnit: {line}\033[0m")
                errors += 1
        finally:
            os.unlink(tmppath)

    return errors, checked


def main():
    try:
        from lib.pretty import pretty
    except ImportError:
        pretty = None

    def _log(category: str, count: int, kind: str = "errors"):
        msg = f"{category}: {count} {kind}"
        if pretty:
            if count:
                pretty.fail(msg)
            else:
                pretty.ok(msg)
        else:
            print(f"  {'✗' if count else '✓'} {msg}")

    def _warn(category: str, count: int):
        msg = f"{category}: {count} warnings"
        if pretty:
            if count:
                pretty.warn(msg)
            else:
                pretty.ok(msg)
        else:
            print(f"  {'⚠' if count else '✓'} {msg}")

    sls_files = sorted(glob.glob("states/**/*.sls", recursive=True))
    jinja_files = sorted(glob.glob("states/*.jinja"))
    yaml_configs = sorted(
        glob.glob("states/configs/*.yaml")
        + glob.glob("states/configs/*.yml")
        + glob.glob("states/data/*.yaml")
    )
    all_jinja = sls_files + jinja_files

    if pretty:
        pretty.section("Salt State Lint")

    total_errors = 0
    total_warnings = 0

    # 1. Jinja2 syntax
    jinja_errors = check_jinja_syntax(all_jinja)
    total_errors += jinja_errors
    _log("Jinja2 syntax", jinja_errors)

    # 2. Duplicate state IDs (also collects rendered docs for later checks)
    dupe_errors, rendered, all_ids, rendered_docs = check_duplicate_state_ids(sls_files)
    total_errors += dupe_errors
    _log("State IDs", dupe_errors)

    # 3. State ID naming conventions
    naming_errors = check_state_id_naming(sls_files, all_ids)
    total_errors += naming_errors
    _log("State ID naming", naming_errors)

    # 4. Host config validation
    host_errors = host_model.check_host_config()
    total_errors += host_errors
    _log("Host config", host_errors)

    # 4b. Feature registry validation
    feature_errors = host_model.check_features_against_registry()
    total_errors += feature_errors
    _log("Feature registry", feature_errors)

    # 5. YAML config validation
    if yaml_configs:
        yaml_errors = check_yaml_configs(yaml_configs)
        total_errors += yaml_errors
        _log("YAML configs", yaml_errors)

    # 6. Unused imports (warning, not error)
    import_warnings = check_unused_imports(sls_files)
    total_warnings += import_warnings
    _warn("Unused imports", import_warnings)

    # 7. Require/watch/onchanges resolution
    require_errors = check_require_resolve(rendered_docs, all_ids)
    total_errors += require_errors
    _log("Require resolve", require_errors)

    # 8. Dangling includes
    include_errors = check_dangling_includes(sls_files)
    total_errors += include_errors
    _log("Dangling includes", include_errors)

    # 9. Data file integrity (required keys, version references)
    data_errors = check_data_integrity()
    total_errors += data_errors
    _log("Data integrity", data_errors)

    # 10. Parse inline suppressions for idempotency and network checks
    suppressions = _parse_suppressions(sls_files)

    # 11. Network resilience (retry + parallel on network commands)
    network_warnings = check_network_resilience(rendered_docs)
    total_warnings += network_warnings
    _warn("Network resilience", network_warnings)

    # 12. Idempotency guards (cmd.run/cmd.script without creates/unless/onlyif/onchanges)
    idempotency_warnings = check_idempotency_guards(rendered_docs, suppressions)
    total_warnings += idempotency_warnings
    _warn("Idempotency guards", idempotency_warnings)

    # 13. Stale suppressions (suppression comment with no matching violation)
    stale_warnings = check_stale_suppressions(sls_files, rendered_docs, suppressions)
    total_warnings += stale_warnings
    _warn("Stale suppressions", stale_warnings)

    # 14. Bash syntax without shell: /bin/bash
    shell_warnings = check_cmd_shell(rendered_docs)
    total_warnings += shell_warnings
    _warn("Cmd shell", shell_warnings)

    # 15. Salt URI references (salt:// paths point to existing files)
    data_yamls = sorted(glob.glob("states/data/*.yaml"))
    uri_errors = check_salt_uri_refs(sls_files, jinja_files, data_yamls)
    total_errors += uri_errors
    _log("Salt URI refs", uri_errors)

    # 16. Systemd unit file validation
    unit_errors, units_checked = check_systemd_units()
    total_errors += unit_errors
    _log("Systemd units", unit_errors)

    # 17. Explicit service inventory contracts
    contract_errors = salt_contracts.print_contract_errors(
        salt_contracts.check_service_inventory_contracts()
    )
    total_errors += contract_errors
    _log("Service inventory contracts", contract_errors)

    if pretty:
        pretty.rule()
        if total_errors:
            pretty.summary_line(0, total_errors, "Lint")
        else:
            pretty.ok(f"Lint: {total_warnings} warnings, 0 errors")
        print()
    else:
        print(f"\n{'─' * 50}")
        print(f"Total: {total_errors} errors, {total_warnings} warnings")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
