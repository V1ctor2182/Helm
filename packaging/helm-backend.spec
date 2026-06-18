# PyInstaller spec for the Helm backend sidecar (onedir).
#
# Built into a self-contained directory that the Electron app bundles as an
# extraResource. uvicorn/fastapi pull a lot of their machinery in dynamically,
# so we collect_all the web stack; the helm package is collected too.
#
# Build:  pyinstaller packaging/helm-backend.spec --noconfirm --distpath dist/backend

import os

from PyInstaller.utils.hooks import collect_all, collect_submodules

# SPECPATH is injected by PyInstaller = this spec's directory (…/packaging).
_REPO_ROOT = os.path.dirname(SPECPATH)
_ENTRY = os.path.join(SPECPATH, "helm_backend.py")

datas, binaries, hiddenimports = [], [], []

for pkg in ("uvicorn", "fastapi", "starlette", "anyio", "click", "h11"):
    d, b, h = collect_all(pkg)
    datas += d
    binaries += b
    hiddenimports += h

hiddenimports += collect_submodules("helm")

a = Analysis(
    [_ENTRY],
    pathex=[_REPO_ROOT],  # so `import helm` resolves from the repo root
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="helm-backend",
    console=True,  # logs to stdout; Electron pipes them
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    name="helm-backend",
)
