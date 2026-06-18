"use strict";

const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const { backendUrl, waitForHealth, resolveBackend } = require("../backend");

test("backendUrl uses loopback defaults", () => {
  assert.strictEqual(backendUrl({}), "http://127.0.0.1:8769");
});

test("backendUrl honors HELM_HOST/HELM_PORT", () => {
  assert.strictEqual(
    backendUrl({ HELM_HOST: "127.0.0.1", HELM_PORT: "9000" }),
    "http://127.0.0.1:9000",
  );
});

test("backendUrl brackets IPv6", () => {
  assert.strictEqual(backendUrl({ HELM_HOST: "::1" }), "http://[::1]:8769");
});

test("waitForHealth resolves true when /healthz is ok", async () => {
  let calls = 0;
  const fetchImpl = async () => {
    calls += 1;
    return { ok: calls >= 2 }; // first call not ready, second ok
  };
  const ok = await waitForHealth("http://x", {
    retries: 5,
    intervalMs: 0,
    fetchImpl,
  });
  assert.strictEqual(ok, true);
  assert.strictEqual(calls, 2);
});

test("waitForHealth resolves false after exhausting retries", async () => {
  let calls = 0;
  const fetchImpl = async () => {
    calls += 1;
    throw new Error("connection refused");
  };
  const ok = await waitForHealth("http://x", {
    retries: 3,
    intervalMs: 0,
    fetchImpl,
  });
  assert.strictEqual(ok, false);
  assert.strictEqual(calls, 3);
});

test("resolveBackend uses python -m helm in dev", () => {
  const { command, args } = resolveBackend({ isPackaged: false, env: {} });
  assert.strictEqual(command, "python3");
  assert.deepStrictEqual(args, ["-m", "helm"]);
});

test("resolveBackend honors HELM_PYTHON in dev", () => {
  const { command } = resolveBackend({
    isPackaged: false,
    env: { HELM_PYTHON: "/x/.venv/bin/python" },
  });
  assert.strictEqual(command, "/x/.venv/bin/python");
});

test("resolveBackend points at the bundled sidecar when packaged", () => {
  const { command, args } = resolveBackend({
    isPackaged: true,
    resourcesPath: "/Apps/Helm.app/Contents/Resources",
    env: {},
  });
  assert.strictEqual(
    command,
    path.join("/Apps/Helm.app/Contents/Resources", "helm-backend", "helm-backend"),
  );
  assert.deepStrictEqual(args, []);
});

test("waitForHealth queries the /healthz path", async () => {
  let seen = null;
  const fetchImpl = async (url) => {
    seen = url;
    return { ok: true };
  };
  await waitForHealth("http://host:1234", { retries: 1, fetchImpl });
  assert.strictEqual(seen, "http://host:1234/healthz");
});
