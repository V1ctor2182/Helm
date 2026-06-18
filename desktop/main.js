"use strict";

// Helm thin Electron shell: spawn the local Python backend, wait until it's
// healthy, then load its URL. The shell carries no business logic — it opens a
// window, manages the backend process lifecycle, and reconnects if the backend
// drops (a crashed backend only blanks the window; relaunch reconnects).

const path = require("node:path");
const { app, BrowserWindow } = require("electron");
const { backendUrl, appUrl, waitForHealth, spawnBackend } = require("./backend");

const LOADING = path.join(__dirname, "loading.html");

let backendProc = null;
let mainWindow = null;
let reconnecting = false;
let quitting = false;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    title: "Helm",
    backgroundColor: "#fafafa",
    webPreferences: { contextIsolation: true, nodeIntegration: false },
  });
  mainWindow.loadFile(LOADING);
  mainWindow.on("closed", () => {
    mainWindow = null;
  });

  // Pin the shell to the local backend: deny popups and block navigation away
  // from the loopback origin (the shell loads only trusted local content).
  const wc = mainWindow.webContents;
  wc.setWindowOpenHandler(() => ({ action: "deny" }));
  wc.on("will-navigate", (event, url) => {
    const allowed = [backendUrl(), appUrl(), "file://"];
    if (!allowed.some((p) => url.startsWith(p))) {
      event.preventDefault();
    }
  });

  // Reconnect: if loading the backend URL fails (backend restarting), wait for
  // health again and retry. Ignore failures loading the local loading page,
  // and guard against overlapping reconnect loops (a retry storm).
  wc.on("did-fail-load", async (_e, _code, _desc, url) => {
    if (!url || !url.startsWith("http") || reconnecting) return;
    reconnecting = true;
    try {
      if (await waitForHealth(backendUrl(), { retries: 20, intervalMs: 500 })) {
        if (mainWindow) await mainWindow.loadURL(appUrl());
      }
    } finally {
      reconnecting = false;
    }
  });
}

async function boot() {
  const url = backendUrl();
  createWindow();

  // If a backend is already serving (dev: run it in a separate terminal), use
  // it; otherwise spawn one unless explicitly told not to.
  const alreadyUp = await waitForHealth(url, { retries: 1, intervalMs: 0 });
  if (!alreadyUp && process.env.HELM_NO_SPAWN !== "1") {
    backendProc = spawnBackend({
      isPackaged: app.isPackaged,
      resourcesPath: process.resourcesPath,
    });
    backendProc.on("exit", (code) => {
      backendProc = null;
      console.error(`[helm] backend exited (code ${code})`);
    });
  }

  if (await waitForHealth(url, { retries: 120, intervalMs: 500 })) {
    if (mainWindow) await mainWindow.loadURL(appUrl());
  } else {
    console.error("[helm] backend never became healthy");
  }
}

// Stop the backend reliably: SIGTERM, then SIGKILL if it doesn't exit in time.
// Without the force-kill fallback a wedged backend keeps holding the port, and
// the next launch silently attaches to that stale process.
function stopBackend() {
  if (!backendProc) return Promise.resolve();
  const proc = backendProc;
  backendProc = null;
  proc.kill("SIGTERM");
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      try {
        proc.kill("SIGKILL");
      } catch {
        // already gone
      }
      resolve();
    }, 2500);
    proc.once("exit", () => {
      clearTimeout(timer);
      resolve();
    });
  });
}

app.whenReady().then(boot);

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) boot();
});

app.on("window-all-closed", () => {
  // macOS-only first version, but keep the conventional guard.
  if (process.platform !== "darwin") app.quit();
});

// Defer the actual quit until the backend is down (will-quit re-fires after
// app.quit(); the `quitting` guard lets it through the second time).
app.on("will-quit", (event) => {
  if (quitting || !backendProc) return;
  event.preventDefault();
  quitting = true;
  stopBackend().finally(() => app.quit());
});
