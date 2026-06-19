"use strict";

// Backend lifecycle helpers for the Electron shell — kept separate from
// main.js (Electron glue) so the readiness handshake is unit-testable without
// launching a window.

const { spawn } = require("node:child_process");
const path = require("node:path");

const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 8769;

/** Build the backend base URL from env (mirrors helm.config defaults). */
function backendUrl(env = process.env) {
  const host = env.HELM_HOST || DEFAULT_HOST;
  const port = env.HELM_PORT || DEFAULT_PORT;
  const h = String(host).includes(":") ? `[${host}]` : host; // bracket IPv6
  return `http://${h}:${port}`;
}

/**
 * URL the window loads. In dev (HELM_DEV=1) it's Vite's HMR server (which
 * proxies /api & /healthz to the backend); in prod it's the backend, which
 * serves the built app. Health checks always target the backend regardless.
 */
function appUrl(env = process.env) {
  if (env.HELM_DEV === "1") return env.HELM_DEV_URL || "http://localhost:5173";
  return backendUrl(env);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Poll `${baseUrl}/healthz` until it returns ok or attempts run out.
 * `fetchImpl` is injectable so tests don't need a real server.
 * Resolves true once healthy, false if it never came up.
 */
async function waitForHealth(
  baseUrl,
  { retries = 60, intervalMs = 500, fetchImpl = fetch } = {},
) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetchImpl(`${baseUrl}/healthz`);
      if (res && res.ok) return true;
    } catch {
      // backend not up yet
    }
    if (i < retries - 1) await sleep(intervalMs);
  }
  return false;
}

/**
 * Decide how to launch the backend, as a {command, args} pair (argv array — no
 * shell, no space-splitting hazards):
 *   - packaged app  → the bundled PyInstaller sidecar under resourcesPath
 *   - dev           → `python -m helm` (HELM_PYTHON overrides the interpreter)
 */
function resolveBackend({
  isPackaged = false,
  resourcesPath = "",
  env = process.env,
} = {}) {
  if (isPackaged) {
    return {
      command: path.join(resourcesPath, "helm-backend", "helm-backend"),
      args: [],
    };
  }
  return { command: env.HELM_PYTHON || "python3", args: ["-m", "helm"] };
}

/** Spawn the backend process. See :func:`resolveBackend` for command selection. */
function spawnBackend(opts = {}) {
  const { command, args } = resolveBackend(opts);
  const env = opts.env || process.env;
  // Dev runs the module from the repo root; the packaged sidecar is
  // self-contained and indifferent to cwd (it uses HELM_DATA_DIR).
  const cwd = opts.isPackaged ? undefined : path.resolve(__dirname, "..");
  return spawn(command, args, { cwd, stdio: "inherit", env });
}

module.exports = {
  DEFAULT_HOST,
  DEFAULT_PORT,
  backendUrl,
  appUrl,
  waitForHealth,
  resolveBackend,
  spawnBackend,
};
