"""Email / calendar room (P2). m1 ships the email side: encrypted IMAP/SMTP
accounts (constraint 9ada9908) + IMAP fetch + a stored inbox. AI triage + draft
(m2), the mail UI (m3), CalDAV calendar (m4), and cross-room linkage + MCP
email_server (m5) follow.

Real IMAP/SMTP connections are external (+ credentials) — the fetch layer is an
injectable interface so the inbox/sync logic is headless-testable with a fake;
live verification against a real mailbox is a [needs-human] task.
"""
