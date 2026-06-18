#!/usr/bin/env bash
# One-command local dev setup: Python venv + backend deps + desktop deps.
# Idempotent — safe to re-run. Verify with `make test`.
set -euo pipefail
cd "$(dirname "$0")/.."

# Pick a Python >= 3.11 (system python3 is often older on macOS).
pick_python() {
  for c in "${HELM_PYTHON:-}" python3.13 python3.12 python3.11 python3; do
    [ -z "$c" ] && continue
    if command -v "$c" >/dev/null 2>&1 && \
       "$c" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,11) else 1)' 2>/dev/null; then
      echo "$c"; return 0
    fi
  done
  echo "ERROR: need Python >= 3.11 — install one or set HELM_PYTHON=/path/to/python" >&2
  return 1
}

PY="$(pick_python)"
echo "==> Python: $("$PY" --version) ($(command -v "$PY"))"

echo "==> creating venv (.venv)"
"$PY" -m venv .venv
.venv/bin/python -m pip install --quiet --upgrade pip

echo "==> installing backend (editable + dev extras)"
.venv/bin/python -m pip install -e ".[dev]"

echo "==> installing desktop deps (npm ci)"
( cd desktop && npm ci )

echo
echo "==> done. Next:"
echo "    make test            # run the validation gate"
echo "    make run             # start the backend (python -m helm)"
echo "    pip install -e '.[packaging]' && make app   # build the .app"
