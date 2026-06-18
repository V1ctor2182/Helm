"""PyInstaller entry point for the bundled backend sidecar.

The Electron shell (m5) launches this frozen executable instead of a system
Python in the packaged app, so users need no Python installed. It's a thin
wrapper around :func:`helm.server.run` — all real logic stays in the package.
"""

from helm.server import run

if __name__ == "__main__":
    run()
