## Design System
Always read `DESIGN.md` before any visual or UI decision on the main workspace
(frontend/). All aesthetic direction, dual black/white theme tokens, typography,
color + daily-accent palette, spacing, layout, motion, and the ORAGE cockpit
chrome rules are defined there. Do not deviate without explicit user approval.
The single design source-of-truth mockup is
`docs/design/helm-pro.html` (locked: A · Instrument Readout + ORAGE cockpit
chrome, black/white themes). Treat it like the notch's helm-notch-pro.html:
read-only design稿, do not edit it — change code to match it. Other files in
`docs/design/` are exploration archive. The notch companion
app's `notch/docs/helm-notch-pro.html` is the shared aesthetic母体. In QA/review,
flag any UI that doesn't match DESIGN.md. No emoji in UI — monochrome SVG or
monospace glyphs only.

## VibeHub
This project uses VibeHub. The `vibehub` MCP server is the team's shared
context layer — pull context before non-trivial edits and record decisions
as you make them. The server advertises its own usage guidance (returned at
connection time) and every tool is self-documented, so consult those rather
than any fixed list here; the available tools evolve and stay discoverable
via the MCP connection without editing this file.
