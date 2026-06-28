#!/usr/bin/env node
/**
 * vibehub-hook — Claude Code hook bridge.
 *
 * Single-file Node ESM, stdlib only (no `npm install` on the user's
 * machine). Reads `.vibehub/config.json` from cwd to get the bearer token
 * and api_url, takes a Claude Code event payload on stdin, and POSTs to
 * the right /api/hooks/* endpoint.
 *
 * Subcommands (must match .claude/settings.json):
 *   session-start   → POST /api/hooks/session-start (caches tool_allowlist)
 *   pre-tool-use    → POST /api/hooks/pre-tool-use (after allowlist check)
 *   post-tool-use   → POST /api/hooks/post-tool-use AND /api/hooks/files-touched
 *
 * Allowlist (decision-rule-018): SessionStart returns the union of tool_filter
 * values across active rules in this user's hierarchy scope. We cache it at
 * `~/.vibehub/session-<session_id>.json` so PreToolUse / PostToolUse can
 * exit 0 immediately for tools no rule cares about, sparing ~80 ms of network
 * round-trip per call.
 *
 * Failure mode: any network/auth error logs to stderr and exits 0 — we never
 * break the user's Claude Code session because of an outage on our side.
 */
import { readFileSync, writeFileSync, mkdirSync, renameSync } from "node:fs";
import { resolve } from "node:path";
import { homedir } from "node:os";
import { execSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { request as httpsRequest } from "node:https";
import { request as httpRequest } from "node:http";

const SUBCOMMAND = process.argv[2];
const VALID = new Set(["session-start", "pre-tool-use", "post-tool-use"]);
const ALLOWLIST_WILDCARD = "*";

if (!VALID.has(SUBCOMMAND)) {
  process.stderr.write(
    `vibehub-hook: unknown subcommand "${SUBCOMMAND}" (expected one of: ${[...VALID].join(", ")})\n`,
  );
  process.exit(0);
}

function loadConfig() {
  const path = resolve(process.cwd(), ".vibehub/config.json");
  try {
    const raw = readFileSync(path, "utf8");
    const cfg = JSON.parse(raw);
    if (!cfg.token || !cfg.api_url) {
      throw new Error("config.json missing token or api_url");
    }
    // repo_root is optional; when present we strip it from any absolute
    // file paths Claude Code hands us so the server gets repo-relative
    // paths it can match against scope_globs and spec_anchors (issue #697).
    // When absent we fall back to `git rev-parse --show-toplevel` once
    // and stash it on the cfg object so subsequent extractFilePaths calls
    // skip the git invocation.
    if (typeof cfg.repo_root !== "string" || !cfg.repo_root) {
      cfg.repo_root = detectRepoRoot();
    }
    return cfg;
  } catch (err) {
    process.stderr.write(`vibehub-hook: cannot read ${path}: ${err.message}\n`);
    process.exit(0);
  }
}

/**
 * Best-effort fallback when config.json doesn't carry repo_root: ask git.
 * Returns null on any failure (not a repo, no git binary, slow fs). The
 * server defends against absolute paths anyway, so a null here just means
 * those paths get filtered server-side instead of stripped client-side.
 */
function detectRepoRoot() {
  try {
    return execSync("git rev-parse --show-toplevel", {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 1500,
    }).trim() || null;
  } catch {
    return null;
  }
}

/**
 * git config remote.origin.url, or null. Used by the server to:
 *   - Cross-check that this token isn't being misused in another repo
 *     (decision-claude-016)
 *   - Auto-resolve project_id for org-wide tokens (decision-claude-015)
 * Failure modes: not a git repo, no origin remote, git binary missing.
 * All return null — the server treats null as "client couldn't tell us".
 */
function getGitRemote() {
  try {
    return execSync("git config --get remote.origin.url", {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      // Cap exec time so a slow filesystem (NFS, fuse) doesn't stall every
      // hook call past the 30s Claude Code soft timeout.
      timeout: 1500,
    }).trim();
  } catch {
    return null;
  }
}

async function readStdin() {
  if (process.stdin.isTTY) return "";
  let buf = "";
  for await (const chunk of process.stdin) buf += chunk;
  return buf;
}

function postJson(apiUrl, path, body, token) {
  const u = new URL(path, apiUrl);
  const isHttps = u.protocol === "https:";
  const lib = isHttps ? httpsRequest : httpRequest;
  const payload = JSON.stringify(body);

  return new Promise((resolve_, reject) => {
    const req = lib(
      {
        hostname: u.hostname,
        port: u.port || (isHttps ? 443 : 80),
        path: u.pathname,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
          Authorization: `Bearer ${token}`,
        },
      },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve_(JSON.parse(data || "{}"));
            } catch {
              resolve_({});
            }
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 200)}`));
          }
        });
      },
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

/**
 * Strip the repo-root prefix from `p` so the server gets a project-relative
 * path (issue #697). Claude Code hands us absolute paths
 * ("/Users/.../foo.ts"); spec_anchors and rule scope_globs are relative
 * ("apps/web/src/foo.ts"), so any absolute path silently misses every match.
 *
 * Boundary cases:
 *   - repoRoot null → return as-is; the server filters absolute paths.
 *   - p exactly equals repoRoot → return "" (don't pass an empty string;
 *     normalize callers drop empty entries).
 *   - p doesn't start with repoRoot → return as-is. Could be a weird
 *     out-of-tree edit; server will filter if absolute.
 */
function toRelative(p, repoRoot) {
  if (!repoRoot) return p;
  // Normalize: trim trailing slash on repoRoot for the prefix compare so
  // "/repo" and "/repo/" both work.
  const root = repoRoot.endsWith("/") ? repoRoot.slice(0, -1) : repoRoot;
  if (p === root) return "";
  if (p.startsWith(root + "/")) return p.slice(root.length + 1);
  return p;
}

function extractFilePaths(event, cfg) {
  // Claude Code's PreToolUse/PostToolUse payload shape varies by tool. We
  // check the common spots: tool_input.file_path, tool_input.path,
  // tool_input.notebook_path, top-level file_paths array.
  const paths = new Set();
  const ti = event?.tool_input ?? {};
  const repoRoot = cfg?.repo_root ?? null;
  const add = (v) => {
    if (typeof v !== "string" || !v) return;
    const rel = toRelative(v, repoRoot);
    if (rel) paths.add(rel);
  };
  for (const key of ["file_path", "path", "notebook_path"]) {
    add(ti[key]);
  }
  if (Array.isArray(ti.file_paths)) {
    for (const p of ti.file_paths) add(p);
  }
  if (Array.isArray(event?.file_paths)) {
    for (const p of event.file_paths) add(p);
  }
  return [...paths];
}

// Per-session cache lives at ~/.vibehub/session-<session_id>.json. Holds:
//   {
//     tool_allowlist: string[],   // ['*'] = wildcard, [] = no rules
//     tool_calls:    { [tool_use_id]: tool_call_id }   // Pre→Post linkage
//   }
//
// All file ops are best-effort — failure (EACCES, missing dir, corrupt JSON)
// silently degrades to "no cache" which means hook script falls back to
// always-call (correct, just slower) and Post fires without tool_call_id
// (server returns 'missing_tool_call_id' warning + cleanup eventually
// resolves the row).
// Whitelist sessionId before using it as a path component. Claude Code uses
// uuids in practice but we don't want to trust JSON-derived strings to stay
// inside ~/.vibehub/.
function isSafeSessionId(sessionId) {
  return typeof sessionId === "string" && /^[a-zA-Z0-9_-]+$/.test(sessionId);
}

function cachePath(sessionId) {
  if (!isSafeSessionId(sessionId)) return null;
  return resolve(homedir(), ".vibehub", `session-${sessionId}.json`);
}

function readCache(sessionId) {
  const p = cachePath(sessionId);
  if (!p) return null;
  try {
    return JSON.parse(readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

// Atomic write — write to a tmp file then rename so concurrent invocations
// can't observe a half-written cache. Per-pid + random suffix keeps two
// parallel hook processes from clobbering each other's tmp files.
function writeCache(sessionId, data) {
  const p = cachePath(sessionId);
  if (!p) return;
  try {
    mkdirSync(resolve(homedir(), ".vibehub"), { recursive: true });
    const tmp = `${p}.tmp.${process.pid}.${randomBytes(4).toString("hex")}`;
    writeFileSync(tmp, JSON.stringify(data));
    renameSync(tmp, p);
  } catch (err) {
    // EACCES, EROFS, etc. — degrade silently. shouldShortCircuit will see
    // no cache and fall back to "always send", which is correct (just slower).
    process.stderr.write(`vibehub-hook: cache write failed: ${err.message}\n`);
  }
}

/**
 * Pre-side short-circuit: skip the network call iff the cached allowlist
 * exists and demonstrably doesn't include this tool.
 *
 *   no cache              → don't short-circuit (cache miss; play safe)
 *   allowlist = []        → short-circuit (no rules at all)
 *   allowlist = ['*']     → don't short-circuit (wildcard rule)
 *   allowlist = [...]     → short-circuit iff toolName ∉ allowlist
 *
 * Defense in depth: server-side match.ts re-applies tool_filter, so a stale
 * cache leaking a tool through still produces correct hits.
 */
function shouldShortCircuitPre(cache, toolName) {
  if (!cache || !Array.isArray(cache.tool_allowlist)) return false;
  if (cache.tool_allowlist.length === 0) return true;
  if (cache.tool_allowlist.includes(ALLOWLIST_WILDCARD)) return false;
  return !cache.tool_allowlist.includes(toolName);
}

/**
 * Post-side short-circuit: same logic as Pre with one important exception —
 * if Pre wrote a tool_call_id for this tool_use_id, Post MUST run the server
 * UPDATE so the row promotes from phase='pre' to 'post'. Skipping it would
 * leave the row pending and force the cleanup cron to mistakenly mark it
 * pre_only or pre_orphaned (state-machine-final.md correctness).
 */
function shouldShortCircuitPost(cache, toolName, toolUseId) {
  // Pre wrote something for this tool_use_id → always run Post.
  if (toolUseId && cache?.tool_calls?.[toolUseId]) return false;
  return shouldShortCircuitPre(cache, toolName);
}

async function main() {
  const cfg = loadConfig();
  const stdin = await readStdin();
  let event = {};
  if (stdin.trim()) {
    try {
      event = JSON.parse(stdin);
    } catch {
      // Claude Code sometimes invokes hooks with no JSON; that's fine.
    }
  }

  // Common envelope sent on every hook POST. project_id may be null
  // when config.json declares an org-wide token — server auto-resolves
  // from git_remote_url in that case (decision-claude-015).
  const env = {
    project_id: cfg.project_id ?? null,
    git_remote_url: getGitRemote(),
  };

  try {
    if (SUBCOMMAND === "session-start") {
      const sessionId = event?.session_id ?? null;
      const res = await postJson(
        cfg.api_url,
        "/api/hooks/session-start",
        { ...env, session_id: sessionId },
        cfg.token,
      );
      // Claude Code 2.x: plain stdout shows in the user's transcript only.
      // To inject into the model's context (so Claude actually reads our
      // rule reminders), output a JSON envelope per the hooks reference.
      if (res?.system_prompt) {
        process.stdout.write(
          JSON.stringify({
            hookSpecificOutput: {
              hookEventName: "SessionStart",
              additionalContext: res.system_prompt,
            },
          }),
        );
      }
      if (res?.warning) process.stderr.write(`vibehub-hook: ${res.warning}\n`);
      // Cache the tool_allowlist so subsequent Pre/Post hooks can early-exit.
      // Wildcard / empty / array — all valid; we just persist what we got.
      if (sessionId && Array.isArray(res?.tool_allowlist)) {
        writeCache(sessionId, {
          tool_allowlist: res.tool_allowlist,
          tool_calls: {},
        });
      }
      process.exit(0);
    }

    if (SUBCOMMAND === "pre-tool-use") {
      const sessionId = event?.session_id ?? null;
      const toolName = event?.tool_name ?? "unknown";
      const cache = readCache(sessionId);

      if (shouldShortCircuitPre(cache, toolName)) {
        process.exit(0);
      }

      const file_paths = extractFilePaths(event, cfg);
      const res = await postJson(
        cfg.api_url,
        "/api/hooks/pre-tool-use",
        {
          ...env,
          tool_name: toolName,
          file_paths,
          session_id: sessionId,
        },
        cfg.token,
      );
      // Claude Code 2.x: plain stdout shows in the user's transcript but
      // does NOT inject into the model's context. Without the JSON
      // envelope below, Claude never sees the rule reminder + tool_call_id
      // and can't autonomously call vibehub.report_compliance — the whole
      // self-report loop (decision-rule-017) breaks.
      // For the block path (exit_code === 2), also emit permissionDecision
      // so Claude Code denies the tool call AND surfaces the reason.
      if (res?.stdout) {
        const isBlock = res?.exit_code === 2;
        process.stdout.write(
          JSON.stringify({
            hookSpecificOutput: {
              hookEventName: "PreToolUse",
              additionalContext: res.stdout,
              ...(isBlock
                ? {
                    permissionDecision: "deny",
                    permissionDecisionReason: res.stdout,
                  }
                : {}),
            },
          }),
        );
      }
      if (res?.warning) process.stderr.write(`vibehub-hook: ${res.warning}\n`);

      // Stash tool_call_id keyed by Anthropic's tool_use_id so PostToolUse can
      // echo it back. Claude Code emits the same tool_use_id on both events.
      // If we don't have a cached allowlist (cache miss / corrupt JSON), only
      // persist the new tool_call mapping — never fabricate an allowlist,
      // since that would defeat the next session's perf optimization.
      const toolUseId = event?.tool_use_id ?? null;
      if (sessionId && toolUseId && typeof res?.tool_call_id === "string") {
        const next = cache && typeof cache === "object"
          ? { ...cache, tool_calls: { ...(cache.tool_calls ?? {}), [toolUseId]: res.tool_call_id } }
          : { tool_calls: { [toolUseId]: res.tool_call_id } };
        writeCache(sessionId, next);
      }
      process.exit(typeof res?.exit_code === "number" ? res.exit_code : 0);
    }

    if (SUBCOMMAND === "post-tool-use") {
      const sessionId = event?.session_id ?? null;
      const toolName = event?.tool_name ?? "unknown";
      const cache = readCache(sessionId);
      const toolUseId = event?.tool_use_id ?? null;

      if (shouldShortCircuitPost(cache, toolName, toolUseId)) {
        process.exit(0);
      }

      const file_paths = extractFilePaths(event, cfg);
      const toolCallId = (toolUseId && cache?.tool_calls?.[toolUseId]) || null;

      // Fire compliance + declarative track in parallel; exit code is
      // determined by the compliance call (it can block via 2).
      const [compliance] = await Promise.all([
        postJson(
          cfg.api_url,
          "/api/hooks/post-tool-use",
          {
            ...env,
            tool_name: toolName,
            file_paths,
            session_id: sessionId,
            tool_call_id: toolCallId ?? null,
          },
          cfg.token,
        ),
        file_paths.length
          ? postJson(
              cfg.api_url,
              "/api/hooks/files-touched",
              {
                ...env,
                file_paths,
                summary: `Claude ${toolName} edit`,
                branch: process.env.VIBEHUB_BRANCH ?? null,
              },
              cfg.token,
            )
          : Promise.resolve(null),
      ]);
      if (compliance?.warning) process.stderr.write(`vibehub-hook: ${compliance.warning}\n`);
      process.exit(
        typeof compliance?.exit_code === "number" ? compliance.exit_code : 0,
      );
    }
  } catch (err) {
    process.stderr.write(`vibehub-hook: ${err.message}\n`);
    process.exit(0);
  }
}

main();
