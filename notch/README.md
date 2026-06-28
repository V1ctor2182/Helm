# Helm Notch

Native macOS notch control panel — a Swift companion app that's a client of the
Helm backend. Four things live in the notch:

1. **Connection** — a dot + version, polling Helm's `/healthz`.
2. **Journal capture** — 速记 / 日记 / 任务 straight into Helm (`/api/notes`, `/api/tasks`).
3. **Agent monitor** — running / waiting-permission agents from `/api/orchestration/runs`.
4. **Media** — now-playing + transport via the private MediaRemote framework.

The panel is a borderless top-center `NSPanel`; tap to expand into the capture
form, click away to collapse. Quit from the menu-bar item.

## Layout

- `Sources/HelmNotchCore` — testable logic: `HelmClient` (backend), `NotchModel`
  (state), media/capture/agent models. No AppKit, no network in tests.
- `Sources/HelmNotchApp` — AppKit/SwiftUI: the notch panel, menu-bar item, and
  `SystemMediaController` (real MediaRemote).

## Develop

```sh
swift build && swift test      # CI runs this on macos-15
swift run HelmNotchApp         # run from source
./package.sh                   # build "Helm Notch.app"; open it, quit from the menu bar
```

Point at a non-default backend with `HELM_NOTCH_URL=http://host:port`.

## Known limits

- **Media now-playing** needs a signed app (or boring.notch's `mediaremote-adapter`):
  macOS 15.4+ withholds MediaRemote data from unsigned binaries — the row stays
  empty and lights up once signing/adapter lands (ticket).
- **Agent Allow/Deny** is read-only for now; interactive permission response
  needs a backend channel (ticket).
