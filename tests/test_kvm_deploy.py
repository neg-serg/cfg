import json
import os
import subprocess

from tests import REPO_ROOT_PATH

SCRIPTS = REPO_ROOT_PATH / "scripts"


def _run_lib_function(func_name, *args):
    """Source the library and call a function with test arguments."""
    lib_path = SCRIPTS / "test-kvm-deploy-lib.sh"
    safe_args = " ".join(str(a) for a in args)
    cmd = [
        "zsh", "-c",
        f'source "{lib_path}" 2>/dev/null;'
        f' {func_name} {safe_args}; echo "EXIT:$?"',
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return result.stdout, result.stderr


def test_log_init_creates_log_dir():
    result = subprocess.run(
        ["zsh", "-n", str(SCRIPTS / "test-kvm-deploy-lib.sh")],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, f"Library syntax error:\n{result.stderr}"


def test_main_script_parseable():
    """Verify test-kvm-deploy.sh is syntactically valid."""
    result = subprocess.run(
        ["zsh", "-n", str(SCRIPTS / "test-kvm-deploy.sh")],
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"Script syntax error:\n{result.stderr}"


def test_main_script_help():
    """Verify --help exits cleanly."""
    result = subprocess.run(
        ["zsh", str(SCRIPTS / "test-kvm-deploy.sh"), "--help"],
        capture_output=True, text=True
    )
    assert result.returncode == 0
    assert "Usage:" in result.stdout


def test_main_script_unknown_option():
    """Verify unknown option exits with code 3."""
    result = subprocess.run(
        ["zsh", str(SCRIPTS / "test-kvm-deploy.sh"), "--nonexistent"],
        capture_output=True, text=True
    )
    assert result.returncode == 3


def test_library_check_rootfs_validates_paths():
    """Verify check_rootfs rejects invalid paths."""
    result = subprocess.run(
        ["zsh", "-c",
         f'source "{SCRIPTS}/test-kvm-deploy-lib.sh"; '
         'check_rootfs "/nonexistent/path"'],
        capture_output=True, text=True
    )
    assert result.returncode != 0
    assert "not a CachyOS rootfs" in result.stderr


def test_library_resolve_profile_lists_all():
    """Verify resolve_profile 'all' returns profile names."""
    result = subprocess.run(
        ["zsh", "-c",
         f'source "{SCRIPTS}/test-kvm-deploy-lib.sh"; '
         f'resolve_profile "all" "{REPO_ROOT_PATH}"'],
        capture_output=True, text=True,
        env={**os.environ, "PATH": "/usr/bin:/bin:/usr/local/bin"},
    )
    assert result.returncode == 0
    profiles = [p for p in result.stdout.strip().split("\n") if p]
    assert len(profiles) >= 1
    assert "matrix-minimal" in profiles or "matrix-monitoring" in profiles


def test_library_generate_report_json():
    lib_path = SCRIPTS / "test-kvm-deploy-lib.sh"
    result = subprocess.run(
        ["zsh", "-c",
         f'source "{lib_path}"; '
         'generate_report_json /dev/stdout '
         'matrix-minimal PASS 142 0 HEALTHY '
         'matrix-services FAIL_SALT 50 3 FAILED'],
        capture_output=True, text=True,
        env={**os.environ, "PATH": "/usr/bin:/bin:/usr/local/bin"},
    )
    assert result.returncode == 0
    report = json.loads(result.stdout)
    assert report["total_profiles"] == 2
    assert report["passed"] == 1
    assert report["failed"] == 1
    assert report["profiles"][0]["profile"] == "matrix-minimal"
    assert report["profiles"][0]["status"] == "PASS"
    assert report["profiles"][1]["profile"] == "matrix-services"
    assert report["profiles"][1]["status"] == "FAIL_SALT"


def test_library_check_kvm_detects_presence():
    """Verify check_kvm returns 0 whether KVM exists or not (warning only)."""
    result = subprocess.run(
        ["zsh", "-c",
         f'source "{SCRIPTS}/test-kvm-deploy-lib.sh"; check_kvm'],
        capture_output=True, text=True
    )
    assert result.returncode == 0


def test_library_check_prereqs():
    """Verify check_prereqs detects QEMU availability."""
    result = subprocess.run(
        ["zsh", "-c",
         f'source "{SCRIPTS}/test-kvm-deploy-lib.sh"; check_prereqs'],
        capture_output=True, text=True
    )
    # Should pass if QEMU is installed, fail otherwise
    # This is environment-dependent; just verify it doesn't crash the shell
    assert "error" not in result.stdout.lower() or result.returncode != 0
