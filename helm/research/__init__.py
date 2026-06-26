"""Deep Research room: an iterative Think→Search→Extract→Synthesize engine that
produces a cited, structured report (intent 25f5b8f3).

m1 ships the engine loop + data model with *injectable* providers, so the
orchestration (≥3 rounds, every claim traced to a source URL — constraint
180077c3) is unit-testable without real web/LLM calls. Real providers + untrusted
-context isolation land in m2; observability/resume in m3; the report view in m4.

NOTE: integration approach deviates from constraint e3f16816 ("reuse Odysseus
engine as-is") — see decision 573932b0 + [needs-human] ticket 123796b8. We reuse
Odysseus's prompt design + loop shape + Helm's chat-provider layer rather than
vendoring the 929-line engine wholesale. Reversible: swap the providers.
"""
