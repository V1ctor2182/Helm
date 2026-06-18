"""HTTP middleware for the platform-shell.

Helm is single-user and local-first: there is no login/auth layer (a fresh
skeleton — we deliberately do NOT port Odysseus's multi-user auth). The trust
boundary is the loopback bind enforced in :mod:`helm.config` — the backend only
listens on 127.0.0.1, so "who can reach it" is "processes on this machine."

What this module adds is defense-in-depth for the browser/WebView that loads the
UI: standard security response headers and a baseline Content-Security-Policy
with a per-request nonce. Feature rooms that need looser framing/CSP (e.g.
embedding rendered reports in an iframe) extend this rather than relax it
globally.
"""

from __future__ import annotations

import secrets

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Baseline CSP. `script-src` is nonce-gated; `style-src` keeps 'unsafe-inline'
# for now (inline style attributes are visual-only and don't execute script).
# {nonce} is filled per request.
_CSP_TEMPLATE = (
    "default-src 'self'; "
    "script-src 'self' 'nonce-{nonce}'; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob:; "
    "media-src 'self' blob:; "
    "connect-src 'self'; "
    "frame-src 'self'; "
    "frame-ancestors 'none'"
)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Attach standard security headers + a per-request CSP nonce to every
    response. The nonce is exposed on ``request.state.csp_nonce`` so server-
    rendered pages can stamp it onto inline <script> tags."""

    async def dispatch(self, request: Request, call_next) -> Response:
        nonce = secrets.token_urlsafe(16)
        request.state.csp_nonce = nonce

        response = await call_next(request)

        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = (
            "camera=(), microphone=(), geolocation=()"
        )
        response.headers["Content-Security-Policy"] = _CSP_TEMPLATE.format(nonce=nonce)
        return response
