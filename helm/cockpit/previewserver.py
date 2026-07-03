"""Isolated HTML preview origin (承 FanBox 预览源隔离,srv:2100-2143):
第二个端口只发静态文件字节——被预览页面运行在 127.0.0.1:8770 自己的 origin 上,
跨源拿不到 8769 的 API 也摸不到应用 DOM,这就是隔离本身。

URL 形如 /fs/<绝对路径>,相对资源(./app.js)自然解析到同目录。
只读、仅 GET、限 $HOME 内、拒绝路径穿越。stdlib 线程服务,零新依赖。
"""

from __future__ import annotations

import mimetypes
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

PREVIEW_PORT = 8770


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, *args: object) -> None:  # 静音默认 stderr 日志
        pass

    def do_GET(self) -> None:  # noqa: N802 (stdlib 命名)
        path = unquote(urlparse(self.path).path)
        if not path.startswith("/fs/"):
            self._err(404)
            return
        target = Path("/" + path[len("/fs/") :]).resolve()
        home = Path.home().resolve()
        # 限 $HOME 内 + 拒绝穿越(resolve 后再验前缀)
        if not target.is_relative_to(home) or not target.is_file():
            self._err(404)
            return
        mime = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        try:
            data = target.read_bytes()
        except OSError:
            self._err(403)
            return
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")  # 改了立刻看到,双缓冲负责不白闪
        self.end_headers()
        self.wfile.write(data)

    def _err(self, code: int) -> None:
        self.send_response(code)
        self.send_header("Content-Length", "0")
        self.end_headers()


def start_preview_server(port: int = PREVIEW_PORT) -> ThreadingHTTPServer | None:
    """Daemon 线程起隔离预览源;端口被占(如另一个 helm 实例)则跳过不致命。"""
    try:
        srv = ThreadingHTTPServer(("127.0.0.1", port), _Handler)
    except OSError:
        return None
    threading.Thread(target=srv.serve_forever, name="helm-preview", daemon=True).start()
    return srv
