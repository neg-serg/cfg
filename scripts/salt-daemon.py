#!/usr/bin/env python3
"""
salt-daemon.py — pre-loaded Salt Caller daemon for faster state.apply

Runs as root. Pre-loads salt modules once, then handles state.apply
requests over a Unix socket without re-loading Python/Salt on each run.

Saves ~0.4s per run by avoiding Python import + salt module loading overhead.

Protocol (line-oriented over Unix socket):
  Client → daemon: single JSON line:
    {"state": "system_description", "kwargs": {"test": true}, "log_file": "/path/to/log"}
  Daemon → client: streaming JSON lines:
    {"type": "stdout", "line": "..."}   -- formatted salt output (summary)
    {"type": "exit",   "code": 0}       -- final exit code

Log file handling:
  - The daemon adds a FileHandler to the root logger writing to the given
    log_file path. This captures "Executing state X for [name]" debug lines
    that salt-apply.sh's awk watcher expects to read via `tail -f`.
  - The formatted salt output summary is written to the log file AND sent
    to the client.

Usage:
  sudo /path/to/.venv/bin/python3 scripts/salt-daemon.py
  sudo /path/to/.venv/bin/python3 scripts/salt-daemon.py --config-dir /path/to/.salt_runtime
  sudo /path/to/.venv/bin/python3 scripts/salt-daemon.py --socket /tmp/salt-daemon.sock

  Client: scripts/salt-apply.sh [state] [--test]
"""

import io
import json
import logging
import os
import queue
import signal
import socket
import struct
import sys
import threading
import time

# ── Salt venv path setup ─────────────────────────────────────────────────────
# Ensure the venv site-packages is on the path when run with system python3.
_SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_VENV_SITE = os.path.join(_SCRIPT_DIR, ".venv", "lib")
if os.path.isdir(_VENV_SITE):
    for _entry in sorted(os.listdir(_VENV_SITE)):
        _candidate = os.path.join(_VENV_SITE, _entry, "site-packages")
        if os.path.isdir(_candidate) and _candidate not in sys.path:
            sys.path.insert(0, _candidate)
            break

# ── Python 3.13+ compatibility shims (PEP 594 removals) ─────────────────────
import salt_compat

salt_compat.patch()

# Patch Salt's _module_dirs to include our custom execution modules.
# (Same approach as salt_runner.py — needed for salt['module.func']() in Jinja.)
import salt.loader as _daemon_salt_loader

_daemon_salt_loader._module_dirs_orig = getattr(
    _daemon_salt_loader, "_module_dirs_orig", None
) or _daemon_salt_loader._module_dirs


def _daemon_patched_module_dirs(*args, **kwargs):
    dirs = _daemon_salt_loader._module_dirs_orig(*args, **kwargs)
    if len(args) > 1 and args[1] == "modules":
        _mod_path = os.path.join(_SCRIPT_DIR, "states", "_modules")
        if _mod_path not in dirs:
            dirs.append(_mod_path)
    return dirs


_daemon_salt_loader._module_dirs = _daemon_patched_module_dirs

# Ensure _modules/ is on sys.path so `from _modules.common import get_host` works
# inside Salt execution modules (Python import, not Salt's module loader).
sys.path.insert(0, os.path.join(_SCRIPT_DIR, "states", "_modules"))

# ── Defaults ─────────────────────────────────────────────────────────────────
_DEFAULT_SOCKET = "/run/salt-daemon.sock"
_DEFAULT_CONFIG_DIR = os.path.join(_SCRIPT_DIR, ".salt_runtime")
_DEFAULT_TIMEOUT = 1800  # 30 minutes per state run (large model downloads)
_DEFAULT_STALL_THRESHOLD = 30


class StateTimeout(Exception):
    """Raised by SIGALRM when a state execution exceeds the timeout."""


def _on_sigalrm(signum, frame):
    raise StateTimeout("state execution timed out")


# ── Security: allowed log directory and state whitelist ──────────────────────
_ALLOWED_LOG_DIR = os.path.join(_SCRIPT_DIR, "logs")


def _discover_allowed_states():
    """Build allowed state set from states/**/*.sls files on disk."""
    import glob

    states_dir = os.path.join(_SCRIPT_DIR, "states")
    found = set()
    for path in glob.glob(os.path.join(states_dir, "**", "*.sls"), recursive=True):
        rel = os.path.relpath(path, states_dir).removesuffix(".sls")
        # Salt uses dot-separated names; also allow slash-separated for convenience
        dot_name = rel.replace(os.sep, ".")
        found.add(dot_name)
        found.add(rel)
    return frozenset(found)


_ALLOWED_STATES = _discover_allowed_states()

log = logging.getLogger("salt-daemon")


# ── Salt loader ───────────────────────────────────────────────────────────────
def load_salt(config_dir: str):
    """Load Salt config, grains, and SMinion once at startup."""
    import salt.config
    import salt.loader
    import salt.minion

    config_file = os.path.join(config_dir, "minion")
    log.info("Loading salt config from %s", config_file)
    opts = salt.config.minion_config(config_file)
    opts["file_client"] = "local"
    opts["local"] = True
    opts["caller"] = True

    # Initialize Salt's logging options dict so forked child processes
    # (parallel: True states) inherit a valid __logging_config__.
    # Without this, Process.__new__ stores None, and the child crashes in
    # set_logging_options_dict(None) → NoneType.get("log_level").
    import salt._logging

    salt._logging.set_logging_options_dict(opts)

    log.info("Loading grains...")
    opts["grains"] = salt.loader.grains(opts)

    log.info("Loading SMinion (modules, states, renderers)...")
    minion = salt.minion.SMinion(opts)

    log.info("Salt ready — %d functions loaded.", len(minion.functions))
    return opts, minion


# ── State runner ──────────────────────────────────────────────────────────────
_LOG_FMT = "%(asctime)s [%(name)-17s:%(lineno)-4d][%(levelname)-8s][%(process)d] %(message)s"

# Known-noisy Salt sub-loggers whose DEBUG records are dropped from the
# per-run log file. Keeps "Executing state X for [name]" (from salt.state)
# visible via tail -f while hiding LazyLoad / loader / renderer chatter.
_NOISY_DEBUG_LOGGERS = (
    "salt.utils.lazy",
    "salt.loader",
    "salt.template",
    "salt.utils.jinja",
    "salt.fileclient",
    "salt.fileserver",
    "salt.loaded.int.module.cmdmod",
)


class _DropNoisyDebugFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if record.levelno >= logging.WARNING:
            return True
        if record.name == "salt.state" and record.levelno == logging.INFO:
            message = record.getMessage()
            return message.startswith(("Running state ", "Completed state "))
        return False


class _ClientProgressHandler(logging.Handler):
    def __init__(
        self,
        emit_line,
        interval: int = 10,
        stall_threshold_seconds: int = _DEFAULT_STALL_THRESHOLD,
        time_source=None,
    ):
        super().__init__(level=logging.INFO)
        self._emit_line = emit_line
        self._interval = interval
        self._stall_threshold_seconds = stall_threshold_seconds
        self._time_source = time_source or time.monotonic
        self._completed = 0
        self._active_state_name = None
        self._active_state_started_at = None
        self._active_state_reported = False
        self._lock = threading.Lock()

    @staticmethod
    def _format_latest_state(name: str, limit: int = 110) -> str:
        normalized = " ".join(name.split())
        if len(normalized) <= limit:
            return normalized
        return normalized[: limit - 3] + "..."

    @staticmethod
    def _extract_state_name(message: str, prefix: str) -> str | None:
        if not message.startswith(prefix):
            return None
        return message.split(prefix, 1)[1].split("]", 1)[0]

    def check_for_stalled_state(self) -> None:
        with self._lock:
            if self._active_state_name is None or self._active_state_reported:
                return
            if self._stall_threshold_seconds <= 0 or self._active_state_started_at is None:
                return
            elapsed = int(self._time_source() - self._active_state_started_at)
            if elapsed < self._stall_threshold_seconds:
                return
            state_name = self._format_latest_state(self._active_state_name)
            self._active_state_reported = True
        self._emit_line(f"[running] {elapsed}s in {state_name}")

    def emit(self, record: logging.LogRecord) -> None:
        try:
            message = record.getMessage()
            if record.levelno >= logging.WARNING:
                self._emit_line(f"[warning] {message}")
                return
            if record.name != "salt.state" or record.levelno != logging.INFO:
                return
            running_state = self._extract_state_name(message, "Running state [")
            if running_state is not None:
                with self._lock:
                    self._active_state_name = running_state
                    self._active_state_started_at = self._time_source()
                    self._active_state_reported = False
                return
            completed_state = self._extract_state_name(message, "Completed state [")
            if completed_state is None:
                return
            latest = self._format_latest_state(completed_state)
            with self._lock:
                self._completed += 1
                if completed_state == self._active_state_name:
                    self._active_state_name = None
                    self._active_state_started_at = None
                    self._active_state_reported = False
                completed = self._completed
            if completed % self._interval != 0:
                return
            self._emit_line(f"[progress] {self._completed} states completed; latest: {latest}")
        except Exception:
            self.handleError(record)


def _summarize_stream(text: str, keep: int = 2) -> list[str]:
    lines = [line for line in text.splitlines() if line.strip()]
    if len(lines) <= keep * 2:
        return lines
    omitted = len(lines) - (keep * 2)
    return [*lines[:keep], f"... {omitted} lines omitted ...", *lines[-keep:]]


def _format_change_block(changes: dict, colorize: bool = True) -> list[str]:
    lines: list[str] = []
    for key, value in changes.items():
        if key in {"stdout", "stderr"} and isinstance(value, str):
            summarized = _summarize_stream(value)
            if not summarized:
                continue
            lines.append(f"              {key}:")
            for entry in summarized:
                lines.append(f"                  {entry}")
            continue
        if colorize:
            try:
                from lib.pretty import pretty as _p
                lines.append(f"              {key}: {_p.bold(str(value))}")
            except ImportError:
                lines.append(f"              {key}: {value}")
        else:
            lines.append(f"              {key}: {value}")
    return lines


def _write_result_json(result: dict, log_file: str | None, state: str) -> None:
    """Write a structured JSON summary alongside the text log.

    The JSON file is placed at <log_file>.json and contains:
      - state: the state name applied
      - success: overall pass/fail
      - summary: {succeeded, failed, changed, total}
      - details: list of {id, result, duration_ms, comment, changes_keys}
    """
    if not log_file:
        return
    json_path = log_file + ".json"
    ordered = sorted(
        (entry for entry in result.values() if isinstance(entry, dict)),
        key=lambda item: item.get("__run_num__", 0),
    )
    details = []
    succeeded = 0
    failed = 0
    changed = 0
    for entry in ordered:
        success = entry.get("result") is not False
        if success:
            succeeded += 1
            if entry.get("changes"):
                changed += 1
        else:
            failed += 1
        details.append({
            "id": entry.get("__id__", entry.get("name", "unknown")),
            "fun": entry.get("fun", "unknown"),
            "name": entry.get("name", ""),
            "result": entry.get("result"),
            "comment": entry.get("comment", ""),
            "duration_ms": entry.get("duration", 0),
            "changed": bool(entry.get("changes")),
        })

    summary = {
        "state": state,
        "success": failed == 0,
        "summary": {
            "succeeded": succeeded,
            "failed": failed,
            "changed": changed,
            "total": len(ordered),
        },
        "details": details,
    }
    try:
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2, sort_keys=True)
    except OSError:
        pass


def _format_compact_highstate(result: dict, colorize: bool = True) -> str:
    ordered = sorted(
        (entry for entry in result.values() if isinstance(entry, dict)),
        key=lambda item: item.get("__run_num__", 0),
    )

    changed = []
    failed = []
    success_count = 0
    failed_count = 0

    for entry in ordered:
        if entry.get("result") is False:
            failed.append(entry)
            failed_count += 1
            continue
        success_count += 1
        if entry.get("changes"):
            changed.append(entry)

    if colorize:
        try:
            from lib.pretty import pretty as _p
        except ImportError:
            colorize = False

    lines = ["local:", ""]
    for entry in [*changed, *failed]:
        is_fail = entry.get("result") is False
        badge = _p.status_badge("FAIL") if (colorize and is_fail) else ""
        entry_color = _p.dim if (colorize and not is_fail) else (lambda s: s)

        lines.append(entry_color("----------"))
        raw_name = entry.get('__id__', entry.get('name', 'unknown'))
        suffix = ' ' + badge if badge else ''
        lines.append(f"      ID: {raw_name}{suffix}")
        lines.append(f"Function: {entry.get('fun', 'unknown')}")
        lines.append(f"    Name: {entry.get('name', '')}")
        lines.append(f"  Result: {entry.get('result')}")
        lines.append(f" Comment: {entry.get('comment', '')}")
        duration = entry.get("duration")
        if duration is not None:
            dur_str = f"Duration: {duration} ms"
            lines.append(dur_str if not colorize else _p.dim(dur_str))
        if entry.get("changes"):
            lines.append("     Changes:")
            lines.append(entry_color("              ----------"))
            lines.extend(_format_change_block(entry["changes"], colorize))

    summary_label = "Summary for local"
    if colorize:
        summary_label = _p.bold(summary_label)

    succeeded_line = f"Succeeded: {success_count}"
    if changed:
        succeeded_line += f" (changed={len(changed)})"
        if colorize:
            succeeded_line = _p.bold(succeeded_line)

    lines.extend(
        [
            "",
            summary_label,
            "--------------",
            succeeded_line,
            f"Failed:      {failed_count}"
            + (f" {_p.status_badge('FAIL')}" if colorize and failed_count else ""),
            "--------------",
            f"Total states run:     {len(ordered)}",
        ]
    )
    return "\n".join(lines) + "\n"


def _highstate_failed(result) -> bool:
    if isinstance(result, dict):
        state_entries = [entry for entry in result.values() if isinstance(entry, dict)]
        if state_entries:
            return any(entry.get("result") is False for entry in state_entries)

        errors = result.get("local")
        if isinstance(errors, list) and errors:
            return True
        if isinstance(errors, str) and errors.strip():
            return True
        return False

    return True


def run_state(
    opts: dict,
    minion,
    state: str,
    kwargs: dict,
    log_file: str,
    client_sock: socket.socket,
) -> int:
    """
    Execute state.sls on the pre-loaded minion and stream output to the client.

    - Adds a FileHandler to the root logger so "Executing state X for [name]"
      debug lines go to log_file (for salt-apply.sh's awk/tail watcher).
    - Captures stdout so salt.output.display_output writes are caught.
    - Appends formatted stdout to log_file (for the awk summary watcher).
    - Sends all output lines to client as {"type": "stdout", "line": "..."}.
    """
    import salt.output

    def send(obj: dict) -> None:
        try:
            client_sock.sendall((json.dumps(obj) + "\n").encode())
        except OSError:
            log.debug("Client disconnected during send")

    # Per-call opts (shallow copy so we don't mutate the shared opts).
    # state_output is NOT overridden here — Salt uses the minion config
    # default (which is the native `highstate` outputter after feature
    # 087's cleanup), so operators see raw Salt output without any
    # custom reformatting.
    run_opts = dict(opts)
    if "state_output" in kwargs:
        run_opts["state_output"] = kwargs["state_output"]
    if kwargs.get("test"):
        run_opts["test"] = True
    # Force ANSI colors even though we capture stdout into a StringIO
    # (which isn't a TTY, so Salt would otherwise auto-disable colors).
    # The color codes get written to the log file and render correctly
    # when streamed via tail -f to the operator's terminal.
    run_opts["color"] = True
    run_opts["force_color"] = True

    # ── Set up file logging ──────────────────────────────────────────────────
    # We need the root logger level at DEBUG so salt's "Executing state X for [name]"
    # messages propagate through named loggers (which inherit from root).  Save and
    # restore the original level so the stderr handler stays at its configured level.
    file_handler = None
    progress_handler = _ClientProgressHandler(
        lambda line: send({"type": "stdout", "line": line}),
        stall_threshold_seconds=_DEFAULT_STALL_THRESHOLD,
    )
    stall_check_stop = threading.Event()
    stall_check_thread = None
    saved_root_level = logging.root.level
    logging.root.addHandler(progress_handler)
    if log_file:
        try:
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            file_handler = logging.FileHandler(log_file, mode="a", encoding="utf-8")
            file_handler.setLevel(logging.DEBUG)
            file_handler.setFormatter(logging.Formatter(_LOG_FMT))
            file_handler.addFilter(_DropNoisyDebugFilter())
            logging.root.addHandler(file_handler)
            # Lower root level so DEBUG records reach the file handler.
            # The stderr handler (basicConfig) retains its own level filter.
            logging.root.setLevel(logging.DEBUG)
        except OSError as exc:
            log.warning("Cannot open log file %s: %s", log_file, exc)

    # ── Run state.sls ────────────────────────────────────────────────────────
    exit_code = 0
    result = None

    def _watch_for_stalled_state() -> None:
        while not stall_check_stop.wait(1.0):
            progress_handler.check_for_stalled_state()

    stall_check_thread = threading.Thread(target=_watch_for_stalled_state, daemon=True)
    stall_check_thread.start()

    try:
        filtered = {k: v for k, v in kwargs.items() if k != "state_output"}
        result = minion.functions["state.sls"](state, **filtered)

        # ── Format and emit output ───────────────────────────────────────
        # Determine exit code from state results before formatting
        if _highstate_failed(result):
            exit_code = 1

        if isinstance(result, dict):
            formatted_output = _format_compact_highstate(result, colorize=True)
            # Write structured JSON result alongside text log
            _write_result_json(result, log_file, state)
        else:
            # Capture display_output (which writes to sys.stdout)
            captured = io.StringIO()
            old_stdout = sys.stdout
            try:
                sys.stdout = captured
                # Non-dict result (error list, etc.)
                salt.output.display_output({"local": result}, out="nested", opts=run_opts)
            finally:
                sys.stdout = old_stdout
            formatted_output = captured.getvalue()

        # Write to log file
        if log_file and formatted_output:
            try:
                with open(log_file, "a", encoding="utf-8") as f:
                    f.write(formatted_output)
            except OSError as exc:
                log.warning("Cannot write output to log file %s: %s", log_file, exc)

        # Send to client
        for line in formatted_output.splitlines():
            send({"type": "stdout", "line": line})

        send({"type": "exit", "code": exit_code})

    except Exception as exc:
        err_msg = f"salt-daemon: error running state.sls({state!r}): {exc}"
        log.exception(err_msg)
        send({"type": "stdout", "line": err_msg})
        send({"type": "exit", "code": 1})
        exit_code = 1

    finally:
        # ── Teardown file handler (always runs, even on timeout/error) ───
        stall_check_stop.set()
        if stall_check_thread is not None:
            stall_check_thread.join(timeout=1.5)
        logging.root.removeHandler(progress_handler)
        progress_handler.close()
        if file_handler is not None:
            logging.root.removeHandler(file_handler)
            file_handler.close()
        logging.root.setLevel(saved_root_level)

    return exit_code


# ── Socket server ─────────────────────────────────────────────────────────────
_EX_TEMPFAIL = 75  # sysexits.h: temporary failure, try again


def _send_busy(conn: socket.socket) -> None:
    """Tell a client the daemon is busy and close the connection gracefully."""
    try:
        busy_msg = "salt-daemon: busy (state already running)"
        msg_line = json.dumps({"type": "stdout", "line": busy_msg})
        exit_line = json.dumps({"type": "exit", "code": _EX_TEMPFAIL})
        conn.sendall(f"{msg_line}\n{exit_line}\n".encode())
        # Graceful shutdown: signal EOF so the client reads the response
        # before we close.  Without this, close() can send RST before
        # the client's recv() sees the data.
        conn.shutdown(socket.SHUT_WR)
        # Drain any remaining client data (the request we won't process)
        conn.settimeout(1.0)
        try:
            while conn.recv(4096):
                pass
        except (OSError, socket.timeout):
            pass
    except OSError:
        pass
    finally:
        conn.close()


class DaemonServer:
    """
    Pre-loaded Salt state daemon with a threaded accept loop.

    Architecture:
      - Accept thread: always listening, instantly rejects with "busy" when a
        state is running.  Pure Python socket I/O — no Salt objects touched.
      - Main thread: pulls one connection from the queue, runs the state.
        Salt's parallel:True states fork() here safely because the accept
        thread holds no Salt-related locks.
    """

    def __init__(self, socket_path: str, opts: dict, minion, timeout: int = _DEFAULT_TIMEOUT):
        self.socket_path = socket_path
        self.opts = opts
        self.minion = minion
        self.timeout = timeout
        self._busy = threading.Event()
        self._conn_queue: queue.Queue[socket.socket] = queue.Queue(maxsize=1)
        self._shutdown_event = threading.Event()
        # Build allowed UID set: root + all members of the wheel group
        import grp
        import pwd

        self.allowed_uids = {0}  # root always allowed
        try:
            wheel = grp.getgrnam("wheel")
            for username in wheel.gr_mem:
                try:
                    self.allowed_uids.add(pwd.getpwnam(username).pw_uid)
                except KeyError:
                    pass
        except KeyError:
            pass
        log.info("Allowed UIDs for socket connections: %s", self.allowed_uids)

    def _check_peer(self, conn: socket.socket) -> bool:
        """Verify peer credentials via SO_PEERCRED. Returns True if allowed."""
        try:
            cred = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("iII"))
            peer_pid, peer_uid, peer_gid = struct.unpack("iII", cred)
        except (OSError, struct.error) as exc:
            log.warning("Cannot get peer credentials: %s", exc)
            return False

        if peer_uid not in self.allowed_uids:
            log.warning(
                "Rejected connection from uid=%d pid=%d (allowed: %s)",
                peer_uid,
                peer_pid,
                self.allowed_uids,
            )
            return False
        return True

    def _accept_loop(self, server: socket.socket) -> None:
        """Accept thread: route connections to the queue or reject as busy."""
        while not self._shutdown_event.is_set():
            try:
                conn, _ = server.accept()
            except OSError:
                break

            if not self._check_peer(conn):
                conn.close()
                continue

            if self._busy.is_set():
                log.info("Rejecting connection — state already running")
                _send_busy(conn)
                continue

            try:
                self._conn_queue.put_nowait(conn)
            except queue.Full:
                log.info("Rejecting connection — queue full")
                _send_busy(conn)

    def handle_client(self, conn: socket.socket) -> None:
        try:
            # Read one newline-terminated JSON line
            data = b""
            conn.settimeout(2.0)
            try:
                while b"\n" not in data:
                    chunk = conn.recv(4096)
                    if not chunk:
                        return
                    data += chunk
            except socket.timeout:
                log.warning("Client timed out during request read (dead connection)")
                return
            finally:
                conn.settimeout(None)

            request = json.loads(data.split(b"\n")[0].decode())
        except (json.JSONDecodeError, OSError, UnicodeDecodeError) as exc:
            log.warning("Bad client request: %s", exc)
            conn.close()
            return

        state = request.get("state", "system_description")
        kwargs = request.get("kwargs", {})
        log_file = request.get("log_file", "")
        req_timeout = request.get("timeout")
        if isinstance(req_timeout, int) and 0 < req_timeout <= 14400:
            effective_timeout = req_timeout
        else:
            effective_timeout = self.timeout

        # ── Validate state name ──────────────────────────────────────────
        # Normalise slash-separated paths to dot-separated Salt state names
        state = state.replace("/", ".")
        if state not in _ALLOWED_STATES:
            log.warning("Rejected disallowed state: %r", state)
            try:
                msg = f"error: state {state!r} not in allowed list"
                conn.sendall((json.dumps({"type": "stdout", "line": msg}) + "\n").encode())
                conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
            except OSError:
                pass
            conn.close()
            return

        # ── Validate log_file path (restrict to project logs/ dir) ───────
        if log_file:
            real_log = os.path.realpath(log_file)
            allowed_dir = os.path.realpath(_ALLOWED_LOG_DIR)
            if not real_log.startswith(allowed_dir + os.sep):
                log.warning(
                    "Rejected log_file outside allowed dir: %r (resolved to %r)",
                    log_file,
                    real_log,
                )
                log_file = ""

        log.info(
            "Request: state=%r kwargs=%s log_file=%r timeout=%ds",
            state,
            kwargs,
            log_file,
            effective_timeout,
        )

        signal.alarm(effective_timeout)
        try:
            run_state(self.opts, self.minion, state, kwargs, log_file, conn)
        except StateTimeout:
            log.error("State %r timed out after %ds", state, effective_timeout)
            try:
                msg = f"error: state {state!r} timed out after {effective_timeout}s"
                conn.sendall((json.dumps({"type": "stdout", "line": msg}) + "\n").encode())
                conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
            except OSError:
                pass
        except Exception as exc:
            log.exception("Unhandled error in run_state: %s", exc)
            try:
                conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
            except OSError:
                pass
        finally:
            signal.alarm(0)

        conn.close()

    def serve(self, socket_path: str) -> None:
        if os.path.exists(socket_path):
            os.unlink(socket_path)

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(socket_path)
        # Allow wheel group to connect so users can send requests without sudo.
        # The daemon itself still runs as root and executes privileged state ops.
        try:
            import grp

            wheel_gid = grp.getgrnam("wheel").gr_gid
            os.chown(socket_path, 0, wheel_gid)
            os.chmod(socket_path, 0o660)
        except (KeyError, OSError):
            # Fallback to root-only if wheel group doesn't exist
            os.chmod(socket_path, 0o600)
        server.listen(5)

        def _shutdown(signum, frame):
            log.info("Received signal %d, shutting down...", signum)
            self._shutdown_event.set()
            server.close()
            if os.path.exists(socket_path):
                try:
                    os.unlink(socket_path)
                except OSError:
                    pass
            sys.exit(0)

        signal.signal(signal.SIGTERM, _shutdown)
        signal.signal(signal.SIGINT, _shutdown)
        signal.signal(signal.SIGALRM, _on_sigalrm)

        # Start accept thread — pure socket I/O, no Salt objects.
        # Salt's fork() in parallel:True states happens in the main thread,
        # so there are no mutex/lock conflicts in the forked child.
        accept_thread = threading.Thread(target=self._accept_loop, args=(server,), daemon=True)
        accept_thread.start()

        print(f"salt-daemon ready on {socket_path}", flush=True)
        log.info("Listening on %s", socket_path)

        while not self._shutdown_event.is_set():
            try:
                conn = self._conn_queue.get(timeout=1.0)
            except queue.Empty:
                continue
            self._busy.set()
            try:
                self.handle_client(conn)
            finally:
                self._busy.clear()


# ── Entry point ───────────────────────────────────────────────────────────────
def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Pre-loaded Salt state daemon (saves ~0.4s per run)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--config-dir",
        default=_DEFAULT_CONFIG_DIR,
        metavar="DIR",
        help="Salt minion config directory",
    )
    parser.add_argument(
        "--socket",
        default=_DEFAULT_SOCKET,
        metavar="PATH",
        help="Unix socket path to listen on",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=_DEFAULT_TIMEOUT,
        metavar="SEC",
        help="Max seconds per state run (0 = no limit)",
    )
    parser.add_argument(
        "--log-level",
        default="warning",
        choices=["debug", "info", "warning", "error"],
        help="Daemon log level",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper()),
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
        stream=sys.stderr,
    )

    if os.geteuid() != 0:
        log.warning("salt-daemon is not running as root — system state changes may fail")

    try:
        opts, minion = load_salt(args.config_dir)
    except Exception as exc:
        log.critical("Failed to load Salt: %s", exc, exc_info=True)
        sys.exit(1)

    server = DaemonServer(args.socket, opts, minion, timeout=args.timeout)
    server.serve(args.socket)


if __name__ == "__main__":
    main()
