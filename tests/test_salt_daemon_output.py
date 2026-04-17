"""Contract tests for compact salt-daemon output formatting."""

import importlib.util
import logging

from tests import REPO_ROOT_PATH


def _load_salt_daemon():
    module_path = REPO_ROOT_PATH / "scripts" / "salt-daemon.py"
    spec = importlib.util.spec_from_file_location("salt_daemon_module", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_compact_highstate_omits_unchanged_states_but_keeps_changed_and_failed_entries():
    salt_daemon = _load_salt_daemon()
    result = {
        "cmd_|-install_tools_|-paru -S --needed foo bar_|-run": {
            "__id__": "install_tools",
            "__run_num__": 0,
            "name": "sudo -u neg paru -S --noconfirm --needed foo bar",
            "fun": "cmd.run",
            "result": True,
            "comment": 'Command "sudo -u neg paru -S --noconfirm --needed foo bar" run',
            "changes": {
                "retcode": 0,
                "stdout": "there is nothing to do\n",
                "stderr": "warning: foo is up to date -- skipping\nwarning: bar is up to date -- skipping\n",
            },
            "duration": 250.0,
        },
        "file_|-/etc/example_|-/etc/example_|-managed": {
            "__id__": "/etc/example",
            "__run_num__": 1,
            "name": "/etc/example",
            "fun": "file.managed",
            "result": True,
            "comment": "File /etc/example is in the correct state",
            "changes": {},
            "duration": 1.0,
        },
        "service_|-broken-service_|-broken-service_|-running": {
            "__id__": "broken-service",
            "__run_num__": 2,
            "name": "broken-service",
            "fun": "service.running",
            "result": False,
            "comment": "Service failed to start",
            "changes": {},
            "duration": 10.0,
        },
    }

    rendered = salt_daemon._format_compact_highstate(result)

    assert "ID: install_tools" in rendered
    assert 'Command "sudo -u neg paru -S --noconfirm --needed foo bar" run' in rendered
    assert "there is nothing to do" in rendered
    assert "warning: foo is up to date -- skipping" in rendered
    assert "ID: broken-service" in rendered
    assert "Service failed to start" in rendered
    assert "File /etc/example is in the correct state" not in rendered
    assert "Succeeded: 2 (changed=1)" in rendered
    assert "Failed:      1" in rendered
    assert "Total states run:     3" in rendered


def test_compact_highstate_truncates_long_cmd_run_streams_without_hiding_edge_lines():
    salt_daemon = _load_salt_daemon()
    result = {
        "cmd_|-verbose_cmd_|-long command_|-run": {
            "__id__": "verbose_cmd",
            "__run_num__": 0,
            "name": "long command",
            "fun": "cmd.run",
            "result": True,
            "comment": 'Command "long command" run',
            "changes": {
                "retcode": 0,
                "stdout": "line1\nline2\nline3\nline4\nline5\nline6\n",
                "stderr": "err1\nerr2\nerr3\nerr4\nerr5\nerr6\n",
            },
            "duration": 12.0,
        }
    }

    rendered = salt_daemon._format_compact_highstate(result)

    assert "line1" in rendered
    assert "line2" in rendered
    assert "line5" in rendered
    assert "line6" in rendered
    assert "line3" not in rendered
    assert "line4" not in rendered
    assert "... 2 lines omitted ..." in rendered
    assert "err1" in rendered
    assert "err6" in rendered


def test_daemon_log_filter_drops_profile_debug_and_cmdmod_noise_but_keeps_progress_and_warnings():
    salt_daemon = _load_salt_daemon()
    log_filter = salt_daemon._DropNoisyDebugFilter()

    profile_record = logging.makeLogRecord(
        {
            "name": "salt.template",
            "levelno": 15,
            "levelname": "PROFILE",
            "msg": "Time to render template",
        }
    )
    debug_record = logging.makeLogRecord(
        {
            "name": "salt.state",
            "levelno": logging.DEBUG,
            "levelname": "DEBUG",
            "msg": "Last command return code: 0",
        }
    )
    cmdmod_info_record = logging.makeLogRecord(
        {
            "name": "salt.loaded.int.module.cmdmod",
            "levelno": logging.INFO,
            "levelname": "INFO",
            "msg": "Executing command 'cat' in directory '/root'",
        }
    )
    progress_record = logging.makeLogRecord(
        {
            "name": "salt.state",
            "levelno": logging.INFO,
            "levelname": "INFO",
            "msg": "Running state [/tmp/example] at time 12:00:00",
        }
    )
    warning_record = logging.makeLogRecord(
        {
            "name": "salt.fileserver",
            "levelno": logging.WARNING,
            "levelname": "WARNING",
            "msg": "Failed to read cache entry",
        }
    )

    assert log_filter.filter(profile_record) is False
    assert log_filter.filter(debug_record) is False
    assert log_filter.filter(cmdmod_info_record) is False
    assert log_filter.filter(progress_record) is True
    assert log_filter.filter(warning_record) is True


def test_compact_highstate_returns_failure_code_for_non_dict_error_results():
    salt_daemon = _load_salt_daemon()

    class DummyMinion:
        functions = {"state.sls": lambda state, **kwargs: ["Rendering SLS failed"]}

    class DummySocket:
        def __init__(self):
            self.messages = []

        def sendall(self, payload):
            self.messages.append(payload.decode().strip())

    sock = DummySocket()
    rc = salt_daemon.run_state({}, DummyMinion(), "system_description", {}, "", sock)

    assert rc == 1
    assert any('"type": "exit", "code": 1' in msg for msg in sock.messages)
