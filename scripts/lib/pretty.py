#!/usr/bin/env python3
"""pretty.py — unified terminal aesthetics for all Python scripts.

Usage:
    from scripts.lib.pretty import pretty
    pretty.header("Deploying system_description")
    pretty.ok("All 65 states valid")
    pretty.fail("zapret2.sls: missing dependency")
    pretty.warn("gopass locked")
    pretty.info("Log: logs/system_description.log")
    pretty.phase("Installing packages", n=3, total=10)
    pretty.progress(67, 100)
    pretty.section("Network Configuration")
    pretty.summary_line(727, 2, "States")
    pretty.service_status("ollama", "active")

    with pretty.spinner("Pulling image"):
        ...slow work...

    # One-liner output capture
    out, rc = pretty.capture("salt_contracts.py", ["python3", "scripts/salt_contracts.py"])
"""

import os
import sys
import time
import shutil
import subprocess
from contextlib import contextmanager

# ── Capability detection ──────────────────────────────────────────────────
_IS_TTY = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
_HAS_UTF8 = any(
    enc in (os.environ.get(k, "") or "")
    for enc in ("UTF-8", "utf-8", "utf8")
    for k in ("LANG", "LC_ALL", "LC_CTYPE")
)

# ── Color palette ─────────────────────────────────────────────────────────
if _IS_TTY:
    C = {
        "reset": "\033[0m", "bold": "\033[1m", "dim": "\033[2m",
        "red": "\033[31m", "green": "\033[32m", "yellow": "\033[33m",
        "blue": "\033[34m", "magenta": "\033[35m", "cyan": "\033[36m",
        "white": "\033[37m", "grey": "\033[90m",
        "red_b": "\033[1;31m", "green_b": "\033[1;32m", "yellow_b": "\033[1;33m",
        "blue_b": "\033[1;34m", "cyan_b": "\033[1;36m", "white_b": "\033[1;37m",
        "grey_b": "\033[1;90m",
    }
else:
    C = {k: "" for k in [
        "reset", "bold", "dim", "red", "green", "yellow", "blue", "magenta",
        "cyan", "white", "grey", "red_b", "green_b", "yellow_b", "blue_b",
        "cyan_b", "white_b", "grey_b",
    ]}

# ── Icons ─────────────────────────────────────────────────────────────────
if _HAS_UTF8:
    I = {
        "ok": "✓", "fail": "✗", "warn": "⚠", "info": "●",
        "phase": "▶", "clock": "⏳", "arrow": "→", "star": "★",
        "bullet": "•", "box_v": "║", "box_h": "═",
        "box_tl": "╔", "box_tr": "╗", "box_bl": "╚", "box_br": "╝",
        "section": "─",
    }
else:
    I = {
        "ok": "OK", "fail": "!!", "warn": "*", "info": ">",
        "phase": ">>", "clock": "...", "arrow": "->", "star": "*",
        "bullet": "-", "box_v": "|", "box_h": "=",
        "box_tl": "+", "box_tr": "+", "box_bl": "+", "box_br": "+",
        "section": "-",
    }

_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] if _HAS_UTF8 else ["/", "-", "\\", "|"]


def _width():
    try:
        return shutil.get_terminal_size().columns
    except Exception:
        return 80


def _repeat(char, count):
    return char * max(count, 0)


class _Pretty:
    """Singleton pretty printer — all methods are static/instance-agnostic."""

    def header(self, text: str):
        w = _width()
        inner = w - 4
        pad_left = max((inner - len(text)) // 2, 0)
        pad_right = max(inner - len(text) - pad_left, 0)
        print(f"{C['cyan_b']}{I['box_tl']}{_repeat(I['box_h'], w-2)}{I['box_tr']}")
        print(f"{I['box_v']}{' '*pad_left}{C['white_b']}{text}{C['cyan_b']}{' '*pad_right} {I['box_v']}")
        print(f"{I['box_bl']}{_repeat(I['box_h'], w-2)}{I['box_br']}{C['reset']}")

    def ok(self, text: str):
        print(f"{C['green_b']} {I['ok']} {C['green']}{text}{C['reset']}")

    def fail(self, text: str):
        print(f"{C['red_b']} {I['fail']} {C['red']}{text}{C['reset']}")

    def warn(self, text: str):
        print(f"{C['yellow_b']} {I['warn']} {C['yellow']}{text}{C['reset']}")

    def info(self, text: str):
        print(f"{C['blue']} {I['info']} {C['reset']}{text}{C['reset']}")

    def phase(self, text: str, n: int | None = None, total: int | None = None):
        if n is not None and total is not None:
            print(f"{C['cyan_b']} {I['phase']} [{n}/{total}] {text}{C['reset']}")
        else:
            print(f"{C['cyan_b']} {I['phase']} {text}{C['reset']}")

    def section(self, text: str):
        w = _width()
        remain = max(w - len(text) - 6, 2)
        print(f"{C['grey_b']}{_repeat(I['section'], 3)} {text} {_repeat(I['section'], remain)}{C['reset']}")

    def progress(self, current: int, total: int):
        bar_w = 30
        pct = current * 100 // max(total, 1)
        filled = bar_w * current // max(total, 1)
        empty = bar_w - filled
        bar = f"{C['green']}{_repeat('█', filled)}{C['grey']}{_repeat('░', empty)}"
        print(f"\r{bar} {C['white_b']}{pct:3d}%{C['reset']}  ({current}/{total})", end="")

    def summary_line(self, passed: int, failed: int, label: str = "Results"):
        w = _width()
        text = f"{label}: {passed} passed"
        if failed:
            text += f", {failed} failed"
        pad = max((w - len(text) - 2) // 2, 0)
        print(f"{C['bold']}{_repeat(I['section'], pad)} {text} {_repeat(I['section'], pad)}{C['reset']}")

    def service_status(self, name: str, status: str):
        if status in ("active", "running", "healthy", "enabled"):
            print(f"{C['green_b']} {I['ok']} {C['green']}{name:<40}{C['reset']} {C['green']}active{C['reset']}")
        elif status in ("failed", "error", "unhealthy", "inactive"):
            print(f"{C['red_b']} {I['fail']} {C['red']}{name:<40}{C['reset']} {C['red']}failed{C['reset']}")
        else:
            print(f"{C['yellow']} {I['warn']} {C['reset']}{name:<40}{C['reset']} {status}")

    @contextmanager
    def spinner(self, text: str = "working"):
        import threading

        stop = threading.Event()
        start_ns = time.monotonic_ns()

        def _spin():
            i = 0
            while not stop.is_set():
                elapsed = int((time.monotonic_ns() - start_ns) / 1e9)
                if elapsed < 60:
                    ts = f"{elapsed}s"
                elif elapsed < 3600:
                    ts = f"{elapsed//60}m{elapsed%60}s"
                else:
                    ts = f"{elapsed//3600}h{(elapsed%3600)//60}m"
                print(f"\r{C['cyan_b']} {_SPINNER[i % len(_SPINNER)]} {C['white']}{text}{C['reset']}  {ts}", end="")
                i += 1
                stop.wait(0.1)

        t = threading.Thread(target=_spin, daemon=True)
        t.start()
        try:
            yield
        finally:
            stop.set()
            t.join(timeout=0.3)
            print("\r" + " " * (_width()) + "\r", end="")

    def capture(self, label: str, cmd: list[str], **kwargs) -> tuple[str, int]:
        """Run a command, capture output, print a one-line status. Returns (stdout, returncode)."""
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
            out = (proc.stdout + proc.stderr).strip()
            rc = proc.returncode
        except Exception as e:
            out = str(e)
            rc = 1

        if rc == 0:
            self.ok(label)
        else:
            self.fail(f"{label} (exit {rc})")
            if out:
                for line in out.splitlines()[:5]:
                    print(f"       {C['dim']}{line}{C['reset']}")
        return out, rc


# Singleton — import as `from scripts.lib.pretty import pretty`
pretty = _Pretty()
