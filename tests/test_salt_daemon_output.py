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


class _FakeClock:
    def __init__(self, now: float):
        self._now = now

    def now(self) -> float:
        return self._now

    def advance(self, seconds: float) -> None:
        self._now += seconds


def _state_record(status: str, state: str, timestamp: str) -> logging.LogRecord:
    return logging.makeLogRecord(
        {
            "name": "salt.state",
            "levelno": logging.INFO,
            "levelname": "INFO",
            "msg": f"{status} state [{state}] at time {timestamp}",
        }
    )


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
                "stderr": "warning: foo is up to date -- skipping\n"
                "warning: bar is up to date -- skipping\n",
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


def test_progress_handler_emits_periodic_completed_state_updates_and_warnings():
    salt_daemon = _load_salt_daemon()
    emitted = []

    handler = salt_daemon._ClientProgressHandler(emitted.append, interval=3)

    for index in range(1, 4):
        handler.emit(
            logging.makeLogRecord(
                {
                    "name": "salt.state",
                    "levelno": logging.INFO,
                    "levelname": "INFO",
                    "msg": f"Completed state [/tmp/state-{index}] at time 12:00:0{index}",
                }
            )
        )

    handler.emit(
        logging.makeLogRecord(
            {
                "name": "salt.fileserver",
                "levelno": logging.WARNING,
                "levelname": "WARNING",
                "msg": "Failed to get mtime on dangling symlink",
            }
        )
    )

    assert emitted[0] == "[progress] 3 states completed; latest: /tmp/state-3"
    assert emitted[1] == "[warning] Failed to get mtime on dangling symlink"


def test_progress_handler_does_not_emit_for_every_completed_state():
    salt_daemon = _load_salt_daemon()
    emitted = []

    handler = salt_daemon._ClientProgressHandler(emitted.append, interval=5)
    for index in range(1, 5):
        handler.emit(
            logging.makeLogRecord(
                {
                    "name": "salt.state",
                    "levelno": logging.INFO,
                    "levelname": "INFO",
                    "msg": f"Completed state [/tmp/state-{index}] at time 12:00:0{index}",
                }
            )
        )

    assert emitted == []


def test_progress_handler_collapses_multiline_state_names_to_single_trimmed_line():
    salt_daemon = _load_salt_daemon()
    emitted = []

    handler = salt_daemon._ClientProgressHandler(emitted.append, interval=1)
    handler.emit(
        logging.makeLogRecord(
            {
                "name": "salt.state",
                "levelno": logging.INFO,
                "levelname": "INFO",
                "msg": "Completed state [set -euo pipefail\n"
                "very long command with many args\n"
                "and more details] at time 12:00:01",
            }
        )
    )

    assert len(emitted) == 1
    assert "\n" not in emitted[0]
    assert "set -euo pipefail very long command with many args and more details" in emitted[0]


def test_progress_handler_truncates_very_long_state_names():
    salt_daemon = _load_salt_daemon()
    emitted = []

    handler = salt_daemon._ClientProgressHandler(emitted.append, interval=1)
    long_name = "x" * 200
    handler.emit(
        logging.makeLogRecord(
            {
                "name": "salt.state",
                "levelno": logging.INFO,
                "levelname": "INFO",
                "msg": f"Completed state [{long_name}] at time 12:00:01",
            }
        )
    )

    assert len(emitted) == 1
    assert len(emitted[0]) < 170
    assert emitted[0].endswith("...")


def test_progress_handler_defaults_to_tighter_update_interval():
    salt_daemon = _load_salt_daemon()
    emitted = []

    handler = salt_daemon._ClientProgressHandler(emitted.append)
    for index in range(1, 11):
        handler.emit(
            logging.makeLogRecord(
                {
                    "name": "salt.state",
                    "levelno": logging.INFO,
                    "levelname": "INFO",
                    "msg": f"Completed state [/tmp/state-{index}] at time 12:00:{index:02d}",
                }
            )
        )

    assert emitted[-1] == "[progress] 10 states completed; latest: /tmp/state-10"


def test_progress_handler_emits_one_running_line_when_active_state_exceeds_threshold():
    salt_daemon = _load_salt_daemon()
    emitted = []
    clock = _FakeClock(100.0)

    handler = salt_daemon._ClientProgressHandler(
        emitted.append,
        interval=10,
        stall_threshold_seconds=10,
        time_source=clock.now,
    )

    handler.emit(_state_record("Running", "/tmp/slow-state", "12:00:00"))
    clock.advance(12)
    handler.check_for_stalled_state()

    assert emitted == ["[running] 12s in /tmp/slow-state"]


def test_progress_handler_emits_running_line_only_once_per_active_state():
    salt_daemon = _load_salt_daemon()
    emitted = []
    clock = _FakeClock(200.0)

    handler = salt_daemon._ClientProgressHandler(
        emitted.append,
        interval=10,
        stall_threshold_seconds=10,
        time_source=clock.now,
    )

    handler.emit(_state_record("Running", "/tmp/slow-state", "12:00:00"))
    clock.advance(11)
    handler.check_for_stalled_state()
    clock.advance(14)
    handler.check_for_stalled_state()

    assert emitted == ["[running] 11s in /tmp/slow-state"]


def test_progress_handler_resets_after_completion_so_next_slow_state_can_report():
    salt_daemon = _load_salt_daemon()
    emitted = []
    clock = _FakeClock(300.0)

    handler = salt_daemon._ClientProgressHandler(
        emitted.append,
        interval=10,
        stall_threshold_seconds=10,
        time_source=clock.now,
    )

    first_running = _state_record("Running", "/tmp/slow-state-1", "12:00:00")
    first_completed = _state_record("Completed", "/tmp/slow-state-1", "12:00:12")
    second_running = _state_record("Running", "/tmp/slow-state-2", "12:01:40")

    handler.emit(first_running)
    clock.advance(12)
    handler.check_for_stalled_state()
    handler.emit(first_completed)
    handler.emit(second_running)
    clock.advance(13)
    handler.check_for_stalled_state()

    assert emitted == [
        "[running] 12s in /tmp/slow-state-1",
        "[running] 13s in /tmp/slow-state-2",
    ]


def test_progress_handler_does_not_emit_running_line_when_state_finishes_quickly():
    salt_daemon = _load_salt_daemon()
    emitted = []
    clock = _FakeClock(500.0)

    handler = salt_daemon._ClientProgressHandler(
        emitted.append,
        interval=10,
        stall_threshold_seconds=10,
        time_source=clock.now,
    )

    handler.emit(_state_record("Running", "/tmp/quick-state", "12:00:00"))
    clock.advance(7)
    handler.emit(_state_record("Completed", "/tmp/quick-state", "12:00:07"))
    handler.check_for_stalled_state()

    assert emitted == []
