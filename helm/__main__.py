"""Allow ``python -m helm`` to boot the backend."""

from helm.server import run

if __name__ == "__main__":
    run()
