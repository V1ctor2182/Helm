"""Journal / notes / tasks room.

m1 ships the unified note store (decision 6c2dd753: one `notes` table + a `kind`
field — note | journal — rather than separate tables, so a quick capture can
become a journal entry by flipping `kind`). Convert-to memory/task/journal is
m2; the journal view m3; scheduled tasks m4; AI summaries m5.
"""
