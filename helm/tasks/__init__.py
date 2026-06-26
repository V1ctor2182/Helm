"""Scheduled tasks (journal-notes-tasks intent#3): cron-style timers that fire
an agent at their due time, recording each run.

m4 ships the data model + schedule math (at/every/cron, decision 894165f7) +
CRUD + note→task + run recording — all transport-free / headless-testable. The
live background scheduler loop + the real agent executor (which makes paid agent
calls) land in m5.
"""
