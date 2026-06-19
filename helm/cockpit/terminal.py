"""PtyProcess: a shell/command running in a pseudo-terminal. Synchronous,
non-blocking master fd — the WS route bridges it to xterm.js. Replaces FanBox's
Node pty path with Python stdlib (constraint 846691dd).
"""

from __future__ import annotations

import fcntl
import os
import struct
import subprocess
import termios


class PtyProcess:
    def __init__(
        self,
        argv: list[str],
        cwd: str | None = None,
        env: dict[str, str] | None = None,
        cols: int = 80,
        rows: int = 24,
    ) -> None:
        self.master, slave = os.openpty()
        self._set_size(cols, rows)
        self.proc = subprocess.Popen(
            argv,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            cwd=cwd,
            env=env,
            start_new_session=True,  # own session+pgrp so signals/job control work
            close_fds=True,
        )
        os.close(slave)
        os.set_blocking(self.master, False)

    def _set_size(self, cols: int, rows: int) -> None:
        winsize = struct.pack("HHHH", rows, cols, 0, 0)
        fcntl.ioctl(self.master, termios.TIOCSWINSZ, winsize)

    def write(self, data: str) -> None:
        os.write(self.master, data.encode("utf-8"))

    def resize(self, cols: int, rows: int) -> None:
        self._set_size(cols, rows)

    def read(self) -> bytes | None:
        """Non-blocking read: bytes with data, b"" on EOF, None if no data yet."""
        try:
            return os.read(self.master, 65536)
        except BlockingIOError:
            return None
        except OSError:
            return b""  # master closed / child gone

    def poll(self) -> int | None:
        return self.proc.poll()

    def close(self) -> None:
        try:
            self.proc.terminate()
        except ProcessLookupError:
            pass
        # Reap the child so it doesn't linger as a zombie. terminate() on a
        # shell returns near-instantly; SIGKILL if it ignores SIGTERM.
        try:
            self.proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
        except ProcessLookupError:
            pass
        try:
            os.close(self.master)
        except OSError:
            pass
