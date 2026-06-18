#!/usr/bin/env bash
# Build the self-contained Helm.app: PyInstaller backend sidecar + Electron shell.
#
# Prereqs: a Python venv with dev+pyinstaller deps, and `npm install` in desktop/.
# Output: dist/desktop/mac*/Helm.app  (unsigned dev build; signing/notarization
# is deferred — needs an Apple Developer cert, see VibeHub question).
#
# Note: when a feature room adds native deps (ChromaDB / onnxruntime), the
# PyInstaller step must be re-validated — those need extra hooks/binaries.
set -euo pipefail
cd "$(dirname "$0")/.."

PYTHON="${HELM_PYTHON:-.venv/bin/python}"

echo "==> building backend sidecar (PyInstaller)"
"$PYTHON" -m PyInstaller packaging/helm-backend.spec --noconfirm \
  --distpath dist/backend --workpath dist/build

echo "==> packaging Electron app (electron-builder)"
cd desktop
CSC_IDENTITY_AUTO_DISCOVERY=false npm run dist

echo "==> done: see dist/desktop/"
