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
 * Spawn the Python backend. In dev this runs the module via an interpreter;
 * packaging (m6) sets HELM_BACKEND_CMD to the bundled PyInstaller sidecar so
 * no system Python is required.
 */
function spawnBackend(env = process.env) {
  const repoRoot = path.resolve(__dirname, "..");
  if (env.HELM_BACKEND_CMD) {
    // TODO(m6): the packaged sidecar path may contain spaces; switch to passing
    // argv as a JSON array (HELM_BACKEND_ARGV) instead of split-on-space.
    const [cmd, ...args] = env.HELM_BACKEND_CMD.split(" ");
    return spawn(cmd, args, { cwd: repoRoot, stdio: "inherit", env });
  }
  const python = env.HELM_PYTHON || "python3";
  return spawn(python, ["-m", "helm"], { cwd: repoRoot, stdio: "inherit", env });
}

module.exports = {
  DEFAULT_HOST,
  DEFAULT_PORT,
  backendUrl,
  waitForHealth,
  spawnBackend,
};
