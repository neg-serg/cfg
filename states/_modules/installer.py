"""Salt execution module: software installers.

Replaces _macros_install.jinja: curl_bin, cargo_pkg, pip_pkg, curl_extract_tar,
curl_extract_zip, http_file, git_clone_deploy, git_clone_build, download_font_zip,
github_release_to, npm_build_workflow, install_catalog, go_pkg, huggingface_file,
firefox_extension.
"""

from __future__ import annotations

from typing import Any

from _yaml_out import yaml_output

from common import _parse_requires


def _host() -> dict[str, Any]:
    try:
        return __salt__["common.get_host"]()
    except (NameError, KeyError):
        try:
            from common import get_host

            return get_host()
        except Exception:
            import os
            import pwd
            _user = os.environ.get("SUDO_USER") or os.environ.get("USER") or "root"
            try:
                _pw = pwd.getpwnam(_user)
                _home = _pw.pw_dir
            except KeyError:
                _home = f"/home/{_user}" if _user != "root" else "/root"
            return {
                "user": _user,
                "home": _home,
                "pkg_list": "/var/cache/salt/pacman_installed.txt",
                "ver_dir": f"{_home}/.cache/salt-versions",
                "sys_ver_dir": "/var/cache/salt/versions",
                "download_cache": "/var/cache/salt/downloads",
            }


def _const() -> dict[str, Any]:
    try:
        return __salt__["common.get_constants"]()
    except (NameError, KeyError):
        try:
            from common import get_constants

            return get_constants()
        except Exception:
            h = _host()
            return {
                "retry_attempts": 3,
                "retry_interval": 10,
                "ver_dir": f"{h.get('home', '/root')}/.cache/salt-versions",
                "sys_ver_dir": "/var/cache/salt/versions",
                "download_cache": "/var/cache/salt/downloads",
            }


def _ver_stamp_shell(ver_dir: str, name: str, version: str, target: str = "") -> str:
    """Generate shell snippet for version stamp."""
    if target:
        return (
            f"mkdir -p {ver_dir} && rm -f {ver_dir}/{name} {ver_dir}/{name}@* && "
            f"ln -sf '{target}' '{ver_dir}/{name}@{version}'"
        )
    return (
        f"mkdir -p {ver_dir} && rm -f {ver_dir}/{name} {ver_dir}/{name}@* && "
        f"touch '{ver_dir}/{name}@{version}'"
    )


def _download_cached_shell(url: str, cache_path: str, hash_val: str = "") -> str:
    lines = [
        f"cache='{cache_path}'",
        'mkdir -p "$(dirname "$cache")"',
        'if [ ! -f "$cache" ]; then',
        f"  curl -fsSL '{url}' -o \"$cache.tmp\"",
    ]
    if hash_val:
        lines.append(f"  echo '{hash_val}  '\"$cache.tmp\" | sha256sum -c --strict")
    lines.extend(
        [
            '  mv -f "$cache.tmp" "$cache"',
            "fi",
        ]
    )
    return "\n".join(lines)


@yaml_output
def go_pkg(
    name: str,
    pkg: str | None = None,
    bin: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    return {
        f"install_{name.replace('-', '_')}": {
            "cmd.run": [
                {"name": f"GOBIN={hm}/.local/bin go install {pkg or name}@latest"},
                {"runas": user or h["user"]},
                {"creates": f"{hm}/.local/bin/{bin or name}"},
                {"parallel": True},
            ]
        }
    }


def _curl_bin_dict(
    name: str,
    url: str,
    version: str | None = None,
    hash_val: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    u = user or h["user"]
    c = _const()
    safe = name.replace("-", "_")
    vd = f"{hm}/.cache/salt-versions"
    cache_dir = c["download_cache"]
    cache_key = f"{name}-{version if version else 'latest'}"
    cache_path = f"{cache_dir}/{cache_key}"

    creates = hm + "/.local/bin/" + name
    creates_ver = f"{vd}/{name}@{version}"

    shell_lines = ["set -eo pipefail"]
    shell_lines.append(_download_cached_shell(url, cache_path, hash_val or ""))
    shell_lines.append(f'cp "$cache" {hm}/.local/bin/{name}.tmp')
    if hash_val and not version:
        shell_lines.append(f"echo '{hash_val}  {hm}/.local/bin/{name}.tmp' | sha256sum -c --strict")
    shell_lines.append(f"chmod +x {hm}/.local/bin/{name}.tmp")
    shell_lines.append(f"mv -f {hm}/.local/bin/{name}.tmp {creates}")
    if version:
        shell_lines.append(_ver_stamp_shell(vd, name, version, target=creates))

    return {
        f"install_{safe}": {
            "cmd.run": [
                {"name": "\n".join(shell_lines)},
                {"runas": u},
                {"shell": "/bin/bash"},
                {"creates": creates_ver if version else creates},
                {"parallel": True},
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
            ]
        }
    }


@yaml_output
def curl_bin(
    name: str,
    url: str,
    version: str | None = None,
    hash_val: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    return _curl_bin_dict(name, url, version=version, hash_val=hash_val, user=user, home=home)


@yaml_output
def cargo_pkg(
    name: str,
    pkg: str | None = None,
    bin: str | None = None,
    git: str | None = None,
    env: str | None = None,
    onlyif: list[str] | None = None,
    version: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    u = user or h["user"]
    safe = name.replace("-", "_")
    vd = f"{hm}/.cache/salt-versions"
    bin_path = f"{hm}/.local/share/cargo/bin/{bin or name}"
    env_pref = f"{env} " if env else ""

    cmd = f"{env_pref}cargo install {'--git ' + git if git else pkg or name}"
    if version:
        cmd += f"\n{_ver_stamp_shell(vd, name, version, target=bin_path)}"

    args: list[dict[str, Any]] = [
        {"name": cmd},
        {"runas": u},
        {"creates": f"{vd}/{name}@{version}" if version else bin_path},
        {"parallel": True},
    ]
    if onlyif:
        args.append({"onlyif": [c for c in onlyif]})

    return {f"install_{safe}": {"cmd.run": args}}


@yaml_output
def pip_pkg(
    name: str,
    pkg: str | None = None,
    bin: str | None = None,
    env: str | None = None,
    preinstall: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    u = user or h["user"]
    safe = name.replace("-", "_")
    env_pref = f"{env} " if env else ""
    preinst = f" --preinstall {preinstall}" if preinstall else ""

    lines = ["set -euo pipefail"]
    lines.append(f"{env_pref}pipx install{preinst} {pkg or name} &>/dev/null || true")
    if preinstall:
        lines.append(
            f"test -x {hm}/.local/bin/{bin or name} || "
            f"{{ pipx uninstall {name} &>/dev/null; "
            f"{env_pref}pipx install{preinst} {pkg or name} &>/dev/null; }}"
        )
    else:
        lines.append(
            f"test -x {hm}/.local/bin/{bin or name} || {env_pref}pipx reinstall {pkg or name}"
        )

    return {
        f"install_{safe}": {
            "cmd.run": [
                {"name": "\n".join(lines)},
                {"runas": u},
                {"shell": "/bin/bash"},
                {"creates": f"{hm}/.local/bin/{bin or name}"},
                {"parallel": True},
            ]
        }
    }


@yaml_output
def http_file(
    name: str,
    url: str,
    dest: str,
    mode: str = "0644",
    user: str | None = None,
    creates: str | None = None,
    require: list[str] | None = None,
    parallel: bool = True,
    hash_val: str | None = None,
    version: str | None = None,
    cache: bool = True,
) -> dict[str, Any]:
    h = _host()
    u = user or h["user"]
    c = _const()
    vd = f"{h['home']}/.cache/salt-versions"

    lines = ["set -eo pipefail"]
    if cache:
        lines.append(_download_cached_shell(url, f"{c['download_cache']}/{name}", hash_val or ""))
        lines.append('src="$cache"')
    else:
        lines.append("src=$(mktemp)")
        lines.append("trap 'rm -f \"$src\"' EXIT")
        lines.append(f"curl -fsSL '{url}' -o \"$src\"")
        if hash_val:
            lines.append(f"echo '{hash_val}  '\"$src\" | sha256sum -c --strict")
    lines.append(f"install -m {mode} -D \"$src\" '{dest}'")
    if version:
        lines.append(_ver_stamp_shell(vd, name, version, target=dest))

    args: list[dict[str, Any]] = [
        {"name": "\n".join(lines)},
        {"shell": "/bin/bash"},
        {"creates": f"{vd}/{name}@{version}" if version else (creates or dest)},
    ]
    if u and u != "root":
        args.append({"runas": u})
    if parallel:
        args.append({"parallel": True})
    args.append({"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}})
    if require:
        args.append({"require": _parse_requires(require)})

    return {name: {"cmd.run": args}}


@yaml_output
def huggingface_file(
    name: str,
    repo: str,
    file: str,
    dest: str,
    mode: str = "0644",
    user: str | None = None,
    creates: str | None = None,
    require: list[str] | None = None,
    parallel: bool = True,
    hash: str | None = None,
    version: str | None = None,
    cache: bool = True,
) -> dict[str, Any]:
    _hash = hash
    return http_file(
        name,
        f"https://huggingface.co/{repo}/resolve/main/{file}",
        dest,
        mode=mode,
        user=user,
        creates=creates,
        require=require,
        parallel=parallel,
        hash_val=_hash,
        version=version,
        cache=cache,
    )


@yaml_output
def git_clone_deploy(
    name: str,
    repo: str,
    dest: str,
    items: list[str] | None = None,
    creates: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    u = user or h["user"]
    hm = home or h["home"]
    c = _const()
    safe = name.replace("-", "_")

    if items:
        lines = [
            "set -eo pipefail",
            "_td=$(mktemp -d)",
            "trap 'rm -rf \"$_td\"' EXIT",
            f'git clone --depth=1 {repo} "$_td/repo"',
            f"mkdir -p {dest}",
        ]
        for item in items:
            lines.append(f'cp -r "$_td/repo"/{item} {dest}/')
    else:
        lines = [
            "set -eo pipefail",
            f"git clone --depth=1 {repo} {dest}",
        ]

    return {
        f"install_{safe}": {
            "cmd.run": [
                {"name": "\n".join(lines)},
                {"runas": u},
                {"shell": "/bin/bash"},
                {"creates": creates or dest.replace("~", hm)},
                {"parallel": True},
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
            ]
        }
    }


@yaml_output
def git_clone_build(
    name: str,
    repo_url: str,
    build_cmds: str,
    binary_src: str,
    binary_dest: str | None = None,
    comment: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    u = user or h["user"]
    c = _const()
    dest = binary_dest or f"{hm}/.local/bin/{name}"

    lines = [
        "set -eo pipefail",
        "_td=$(mktemp -d)",
        "trap 'rm -rf \"$_td\"' EXIT",
        f'GIT_CONFIG_GLOBAL=/dev/null git clone --depth=1 {repo_url} "$_td/{name}"',
        f'cd "$_td/{name}"',
        build_cmds,
        f'install -m 0755 "$_td/{name}/{binary_src}" {dest}',
    ]

    return {
        name: {
            "cmd.run": [
                {"name": "\n".join(lines)},
                {"runas": u},
                {"shell": "/bin/bash"},
                {"creates": dest},
                {"parallel": True},
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
            ]
        }
    }


def _curl_extract_tar_dict(
    name: str,
    url: str,
    binary_pattern: str | None = None,
    archive_ext: str = "tar.gz",
    fetch_tag: bool = False,
    strip_v: bool = False,
    binaries: list[str] | None = None,
    bin: str | None = None,
    chmod: bool = False,
    dest: str | None = None,
    strip_components: int | None = None,
    creates: str | None = None,
    bin_dest: str | None = None,
    hash_val: str | None = None,
    version: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    u = user or h["user"]
    c = _const()
    safe = name.replace("-", "_")
    ext_flag = "J" if archive_ext == "tar.xz" else "z"
    target_dir = bin_dest or "~/.local/bin"
    vd = f"{hm}/.cache/salt-versions"
    cache_key = f"{name}-{version if version else 'latest'}"
    cache_path = f"{c['download_cache']}/{cache_key}.{archive_ext}"

    if not creates:
        if dest:
            creates = dest.replace("~", hm)
        elif binaries:
            creates = f"{target_dir.replace('~', hm)}/{binaries[0]}"
        elif bin:
            creates = f"{target_dir.replace('~', hm)}/{bin}"
        elif binary_pattern:
            creates = f"{target_dir.replace('~', hm)}/{binary_pattern.rsplit('/', 1)[-1]}"
        else:
            creates = f"{hm}/.local/bin/{name}"

    repo_path = ""
    if fetch_tag:
        if "/api.github.com/repos/" in url:
            repo_path = "/".join(url.split("/repos/")[1].split("/")[:2])
        else:
            repo_path = "/".join(url.split("github.com/")[1].split("/")[:2])

    lines = [
        "set -eo pipefail",
        "_td=$(mktemp -d)",
        "trap 'rm -rf \"$_td\"' EXIT",
    ]

    if fetch_tag:
        lines.extend(
            [
                f"TAG=$(curl -fsSIL -o /dev/null -w '%{{url_effective}}' "
                f"https://github.com/{repo_path}/releases/latest | rg -oP '[^/]+$')",
            ]
        )
        if strip_v:
            lines.append("VER=${TAG#v}")
        lines.append(f"cache='{c['download_cache']}/{name}-'\"${{TAG:-latest}}.{archive_ext}\"")
        lines.extend(
            [
                'mkdir -p "$(dirname "$cache")"',
                'if [ ! -f "$cache" ]; then',
                f'  curl -fsSL "{url}" -o "$cache.tmp"',
                '  mv -f "$cache.tmp" "$cache"',
                "fi",
            ]
        )
    else:
        lines.append(_download_cached_shell(url, cache_path, hash_val or ""))

    lines.append(f'cp "$cache" "$_td/archive.{archive_ext}"')

    if dest:
        lines.append(f"mkdir -p {dest}")
        lines.append(
            f'tar -x{ext_flag}f "$_td/archive.{archive_ext}" -C {dest}'
            + (f" --strip-components={strip_components}" if strip_components else "")
        )
    else:
        lines.append(f'tar -x{ext_flag}f "$_td/archive.{archive_ext}" -C "$_td"')
        if binaries:
            for b in binaries:
                if binary_pattern and "*" in binary_pattern:
                    lines.append(
                        f'install -m 0755 "$_td"/{binary_pattern.replace("*", b)}/'
                        f"{b} {target_dir}/ 2>/dev/null || install -m 0755 "
                        f'"$_td"/{binary_pattern.rsplit("/", 1)[0]}/{b} {target_dir}/'
                    )
                else:
                    lines.append(f'install -m 0755 "$_td"/{binary_pattern or ""}/{b} {target_dir}/')
        else:
            bp = binary_pattern or name
            lines.append(
                f'find "$_td" -maxdepth 3 -path "*{bp}*" -type f '
                f'! -name "*.tar*" -exec install -m 0755 {{}} '
                f"{target_dir}/{bin or bp.rsplit('/', 1)[-1]} \\;"
            )
        if chmod:
            for b in binaries or [
                bin or binary_pattern.rsplit("/", 1)[-1] if binary_pattern else name
            ]:
                lines.append(f"chmod +x {target_dir}/{b}")

    if version:
        lines.append(_ver_stamp_shell(vd, name, version, target=creates))

    return {
        f"install_{safe}": {
            "cmd.run": [
                {"name": "\n".join(lines)},
                {"runas": u},
                {"shell": "/bin/bash"},
                {"creates": f"{vd}/{name}@{version}" if version else creates},
                {"parallel": True},
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
            ]
        }
    }


@yaml_output
def curl_extract_tar(
    name: str,
    url: str,
    binary_pattern: str | None = None,
    archive_ext: str = "tar.gz",
    fetch_tag: bool = False,
    strip_v: bool = False,
    binaries: list[str] | None = None,
    bin: str | None = None,
    chmod: bool = False,
    dest: str | None = None,
    strip_components: int | None = None,
    creates: str | None = None,
    bin_dest: str | None = None,
    hash_val: str | None = None,
    version: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    return _curl_extract_tar_dict(
        name,
        url,
        binary_pattern=binary_pattern,
        archive_ext=archive_ext,
        fetch_tag=fetch_tag,
        strip_v=strip_v,
        binaries=binaries,
        bin=bin,
        chmod=chmod,
        dest=dest,
        strip_components=strip_components,
        creates=creates,
        bin_dest=bin_dest,
        hash_val=hash_val,
        version=version,
        user=user,
        home=home,
    )


def _curl_extract_zip_dict(
    name: str,
    url: str,
    binary_path: str | None = None,
    binaries: list[str] | None = None,
    bin: str | None = None,
    chmod: bool = False,
    dest: str | None = None,
    symlink: str | None = None,
    creates: str | None = None,
    hash_val: str | None = None,
    version: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    u = user or h["user"]
    c = _const()
    safe = name.replace("-", "_")
    vd = f"{hm}/.cache/salt-versions"
    cache_key = f"{name}-{version if version else 'latest'}"
    cache_path = f"{c['download_cache']}/{cache_key}.zip"
    out_name = bin or (
        binaries[0] if binaries else (binary_path.rsplit("/", 1)[-1] if binary_path else name)
    )

    if not creates:
        creates = (dest.replace("~", hm)) if dest else f"{hm}/.local/bin/{out_name}"

    lines = [
        "set -eo pipefail",
        "_td=$(mktemp -d)",
        "trap 'rm -rf \"$_td\"' EXIT",
        _download_cached_shell(url, cache_path, hash_val or ""),
        'cp "$cache" "$_td/archive.zip"',
    ]

    if dest:
        lines.append(f"mkdir -p {dest}")
        lines.append(f'unzip -o "$_td/archive.zip" -d {dest}')
        if symlink:
            lines.append(f"ln -sf {dest}/{symlink} ~/.local/bin/{name}")
    else:
        lines.append('unzip -o "$_td/archive.zip" -d "$_td"')
        if binaries:
            for b in binaries:
                lines.append(f'mv "$_td"/{binary_path}/{b} ~/.local/bin/')
        elif bin:
            lines.append(f'mv "$_td"/{binary_path} ~/.local/bin/{bin}')
        else:
            lines.append(f'mv "$_td"/{binary_path} ~/.local/bin/{binary_path.rsplit("/", 1)[-1]}')
        if chmod:
            for b in binaries or [out_name]:
                lines.append(f"chmod +x ~/.local/bin/{b}")

    if version:
        lines.append(_ver_stamp_shell(vd, name, version, target=creates))

    return {
        f"install_{safe}": {
            "cmd.run": [
                {"name": "\n".join(lines)},
                {"runas": u},
                {"shell": "/bin/bash"},
                {"creates": f"{vd}/{name}@{version}" if version else creates},
                {"parallel": True},
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
            ]
        }
    }


@yaml_output
def curl_extract_zip(
    name: str,
    url: str,
    binary_path: str | None = None,
    binaries: list[str] | None = None,
    bin: str | None = None,
    chmod: bool = False,
    dest: str | None = None,
    symlink: str | None = None,
    creates: str | None = None,
    hash_val: str | None = None,
    version: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    return _curl_extract_zip_dict(
        name,
        url,
        binary_path=binary_path,
        binaries=binaries,
        bin=bin,
        chmod=chmod,
        dest=dest,
        symlink=symlink,
        creates=creates,
        hash_val=hash_val,
        version=version,
        user=user,
        home=home,
    )


@yaml_output
def download_font_zip(
    name: str,
    url: str,
    subdir: str,
    hash: str | None = None,
    version: str | None = None,
    user: str | None = None,
    home: str | None = None,
) -> dict[str, Any]:
    h = _host()
    hm = home or h["home"]
    _hash = hash
    u = user or h["user"]
    c = _const()
    fonts_dir = f"{hm}/.local/share/fonts"
    cache_key = f"{name}-{version if version else 'latest'}"
    cache_path = f"{c['download_cache']}/{cache_key}.zip"

    ret: dict[str, Any] = {
        f"{name}_font_dir": {
            "file.directory": [
                {"name": f"{fonts_dir}/{subdir}"},
                {"user": u},
                {"group": u},
                {"makedirs": True},
            ]
        }
    }

    lines = [
        "set -eo pipefail",
        "_td=$(mktemp -d)",
        "trap 'rm -rf \"$_td\"' EXIT",
        _download_cached_shell(url, cache_path, _hash or ""),
        'cp "$cache" "$_td/archive.zip"',
        f'unzip -o "$_td/archive.zip" -d {fonts_dir}/{subdir}',
        f"fc-cache -f {fonts_dir}/{subdir}",
        f"rm -f {fonts_dir}/{subdir}/.salt-installed {fonts_dir}/{subdir}/.salt-installed@*",
    ]

    if version:
        lines.append(f"touch {fonts_dir}/{subdir}/.salt-installed@{version}")
    else:
        lines.append(f"touch {fonts_dir}/{subdir}/.salt-installed")

    ret[f"install_{name}"] = {
        "cmd.run": [
            {"name": "\n".join(lines)},
            {"runas": u},
            {"shell": "/bin/bash"},
            {
                "creates": f"{fonts_dir}/{subdir}/.salt-installed@{version}"
                if version
                else f"{fonts_dir}/{subdir}/.salt-installed"
            },
            {"parallel": True},
            {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
            {"require": [{"file": f"{name}_font_dir"}]},
        ]
    }

    # Fallback guard for non-versioned installs
    if not version:
        ret[f"install_{name}"]["cmd.run"].append(
            {
                "unless": (
                    f'S="{fonts_dir}/{subdir}/.salt-installed"; '
                    f'[ -f "$S" ] && exit 0; '
                    f"find {fonts_dir}/{subdir} -maxdepth 1 "
                    f"\\( -name '*.otf' -o -name '*.ttf' \\) -print -quit 2>/dev/null | grep -q ."
                )
            }
        )

    return ret


@yaml_output
def github_release_to(
    state_id: str,
    name: str,
    repo: str,
    asset: str,
    dest: str,
    format: str = "file",
    tag: str | None = None,
    hash_val: str | None = None,
    version: str | None = None,
    creates: str | None = None,
    require: str | None = None,
    user: str | None = None,
) -> dict[str, Any]:
    h = _host()
    u = user or h["user"]
    c = _const()
    vd = f"{h['home']}/.cache/salt-versions"
    creates_path = creates or f"{dest}/{name}"
    _format = format

    lines = ["set -eo pipefail"]
    if tag:
        lines.append(f'TAG="{tag}"')
    else:
        lines.extend(
            [
                f"TAG=$(curl -fsSIL -o /dev/null -w '%{{url_effective}}' "
                f"https://github.com/{repo}/releases/latest | rg -oP '[^/]+$')",
                f'[ -n "$TAG" ] || '
                f'{{ echo "Failed to fetch release tag for {repo}" >&2; exit 1; }}',
            ]
        )

    if _format == "zip":
        lines.extend(
            [
                "_td=$(mktemp -d)",
                "trap 'rm -rf \"$_td\"' EXIT",
                (
                    f'curl -fsSL "https://github.com/{repo}/releases/download/${{TAG}}/{asset}" '
                    f'-o "$_td/archive.zip"'
                ),
            ]
        )
        if hash_val:
            lines.append(f"echo '{hash_val}  '\"$_td/archive.zip\" | sha256sum -c --strict")
        lines.append(f'unzip -qo "$_td/archive.zip" -d {dest}')
    else:
        lines.append(
            f'curl -fsSL "https://github.com/{repo}/releases/download/${{TAG}}/{asset}" '
            f"-o '{dest}/{name}.tmp'"
        )
        if hash_val:
            lines.append(f"echo '{hash_val}  {dest}/{name}.tmp' | sha256sum -c --strict")
        lines.append(f"mv -f '{dest}/{name}.tmp' '{dest}/{name}'")

    if version:
        lines.append(_ver_stamp_shell(vd, name, version, target=creates_path))

    args: list[dict[str, Any]] = [
        {"name": "\n".join(lines)},
        {"runas": u},
        {"shell": "/bin/bash"},
        {"creates": f"{vd}/{name}@{version}" if version else creates_path},
        {"parallel": True},
        {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
    ]
    if require:
        args.append({"require": _parse_requires([require])})

    return {state_id: {"cmd.run": args}}


@yaml_output
def npm_build_workflow(
    name: str,
    dir: str,
    version: str | None = None,
    install_creates: str | None = None,
    build_creates: str | None = None,
    user: str | None = None,
    require: list[str] | None = None,
) -> dict[str, Any]:
    h = _host()
    u = user or h["user"]
    c = _const()
    _dir = dir

    i_creates = install_creates or f"{_dir}/node_modules/.package-lock.json"
    b_creates = build_creates or f"{_dir}/dist/index.js"

    ret: dict[str, Any] = {
        f"{name}_npm_install": {
            "cmd.run": [
                {"name": f"set -euo pipefail\ncd {_dir}\nnpm install --no-fund --no-audit 2>&1"},
                {"shell": "/bin/bash"},
                {"runas": u},
                {"creates": i_creates},
            ]
        },
        f"{name}_build": {
            "cmd.run": [
                {"name": f"set -euo pipefail\ncd {_dir}\nnpm run build 2>&1"},
                {"shell": "/bin/bash"},
                {"runas": u},
                {"creates": b_creates},
                {"require": [{"cmd": f"{name}_npm_install"}]},
            ]
        },
    }

    if require and f"{name}_npm_install" in ret:
        ret[f"{name}_npm_install"]["cmd.run"].append({"require": _parse_requires(require)})

    if version:
        ret[f"{name}_version"] = {
            "cmd.run": [
                {
                    "name": (
                        f"set -euo pipefail\ncd {_dir}\n"
                        f"git fetch --tags --depth=1\n"
                        f"git checkout v{version} 2>/dev/null || git checkout {version}\n"
                        f"npm install --no-fund --no-audit 2>&1\n"
                        f"npm run build 2>&1"
                    )
                },
                {"shell": "/bin/bash"},
                {"runas": u},
                {
                    "unless": (
                        f"cd {_dir} && git describe --tags --exact-match "
                        f"2>/dev/null | grep -qxF 'v{version}'"
                    )
                },
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
                {"require": [{"cmd": f"{name}_build"}]},
            ]
        }

    return ret


@yaml_output
def install_catalog(
    catalog: dict[str, Any],
    ver_dict: dict[str, str],
    macro_type: str,
    exclude: list[str] | None = None,
) -> dict[str, Any]:
    """Data-driven installer dispatcher — replaces install_catalog() macro."""
    ret: dict[str, Any] = {}
    exclude_set = set(exclude or [])

    for entry_name, raw in catalog.items():
        if entry_name in exclude_set:
            continue

        ver = ver_dict.get(entry_name.replace("-", "_"), "")
        if isinstance(raw, dict):
            url = raw["url"].replace("${VER}", ver)
            hash_val = raw.get("hash")
        else:
            url = raw.replace("${VER}", ver)
            hash_val = None

        if macro_type == "curl_bin":
            ret.update(
                _curl_bin_dict(
                    entry_name,
                    url,
                    version=ver if ver else None,
                    hash_val=hash_val,
                )
            )
        elif macro_type == "curl_extract_tar":
            ret.update(
                _curl_extract_tar_dict(
                    entry_name,
                    url,
                    binary_pattern=raw.get("binary_pattern")
                    if isinstance(raw, dict)
                    else entry_name,
                    bin=raw.get("bin") if isinstance(raw, dict) else None,
                    version=ver if ver else None,
                    hash_val=hash_val,
                )
            )
        elif macro_type == "curl_extract_zip":
            ret.update(
                _curl_extract_zip_dict(
                    entry_name,
                    url,
                    binary_path=raw.get("binary_path") if isinstance(raw, dict) else None,
                    binaries=raw.get("binaries") if isinstance(raw, dict) else None,
                    chmod=raw.get("chmod", False) if isinstance(raw, dict) else False,
                    dest=raw.get("dest") if isinstance(raw, dict) else None,
                    symlink=raw.get("symlink") if isinstance(raw, dict) else None,
                    version=ver if ver else None,
                    hash_val=hash_val,
                )
            )

    return ret
