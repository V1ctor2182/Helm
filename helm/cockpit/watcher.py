"""Directory watcher (watchdog) — replaces FanBox's Node chokidar. Emits
{path, kind} per file change; the route streams them to the dashboard and
records them. Callbacks fire on watchdog's own thread (not the event loop).
"""

from __future__ import annotations

from collections.abc import Callable

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

ChangeCallback = Callable[[dict], None]

_KINDS = {"created", "modified", "deleted", "moved"}


class _Handler(FileSystemEventHandler):
    def __init__(self, callback: ChangeCallback) -> None:
        self._cb = callback

    def on_any_event(self, event: FileSystemEvent) -> None:
        if event.is_directory or event.event_type not in _KINDS:
            return
        # moved events report the destination as the "current" path.
        path = getattr(event, "dest_path", "") or event.src_path
        self._cb({"path": path, "kind": event.event_type})


class DirWatcher:
    def __init__(self, path: str, callback: ChangeCallback) -> None:
        self._observer = Observer()
        self._observer.schedule(_Handler(callback), path, recursive=True)

    def start(self) -> None:
        self._observer.start()

    def stop(self) -> None:
        self._observer.stop()
        self._observer.join(timeout=2)
