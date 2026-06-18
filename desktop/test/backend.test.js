"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { backendUrl, waitForHealth } = require("../backend");

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

test("waitForHealth queries the /healthz path", async () => {
  let seen = null;
  const fetchImpl = async (url) => {
    seen = url;
    return { ok: true };
  };
  await waitForHealth("http://host:1234", { retries: 1, fetchImpl });
  assert.strictEqual(seen, "http://host:1234/healthz");
});
