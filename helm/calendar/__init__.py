"""Calendar (email-calendar intent#2): local-first events with .ics import/
export and a CalDAV sync seam.

m4 ships local events + CRUD + minimal .ics parse/serialize (no dep) + an
encrypted CalDAV account model + a mockable sync interface. Real CalDAV
bidirectional sync (external) is a [needs-human] integration — the sync logic
is driven by an injectable client so the local side is headless-testable.
"""
