"""Process entry point: ``python -m helm`` boots the backend on loopback.

The desktop shell (m5, thin Electron) spawns this as its backend process and
loads ``http://127.0.0.1:<port>`` once ``/healthz`` is green.
"""

from __future__ import annotations

import uvicorn

from helm.app import create_app
from helm.config import HelmConfig


def run() -> None:
    config = HelmConfig.from_env()
    app = create_app(config)
    uvicorn.run(app, host=config.host, port=config.port, log_level="info")


if __name__ == "__main__":
    run()
