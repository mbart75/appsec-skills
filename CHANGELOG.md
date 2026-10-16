# Changelog

## Unreleased

- `appsec-review`: first version. Modes `diff`, `full`, `pre-launch`, `verify`; report designed as a work order (stable IDs, "Done when", status, hand-off); scanner runner for 11 tools; 16 reference checklists.
- Test bench: TinyShop with 37 seeded flaws, its fixed counterpart with 7 traps, answer key and scoring procedure.

## Bench results

Recall is out of the number of seeded flaws at the time of the run. Full mode, scanners installed, blind copy built by `bench/setup.sh`.

| Date | Skill | Agent / model | Variant | Recall | Trap hits | False positives | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-16 | none (baseline) | Claude Opus 5.5 | vulnerable | 35/35 | n/a | 0 | One hard-coded password copied verbatim into the report. No per-finding verification criteria, no status field |
| 2026-10-16 | none (baseline) | Claude Opus 5.5 | secure | n/a | 0 | 0 | Found two real flaws left in secure-app (now V36 and a fixed deploy guard) |
| 2026-10-16 | none (baseline) | Claude Haiku 5.5 | vulnerable | 36/36 | n/a | 0 | Report outside the repository without being told |
| 2026-10-16 | appsec-review draft | Claude Haiku 5.5 | vulnerable | 35/36 | n/a | 0 | 34 found, 2 rated below the floor at the time (floor later lowered to Low for V28 and V32, see key notes). Every finding had location, scenario, fix, "Done when" and status; no secret leaked |
| 2026-10-16 | appsec-review draft | Claude Haiku 5.5 | secure | n/a | 0.5 | 1 | Anon key listed as an Info finding while judged "public by design"; one speculative finding. Found a real flaw (now V37). Led to the "work order" placement rule |
| 2026-10-16 | appsec-review + placement rule | Claude Haiku 5.5 | secure | n/a | 0 | 0 | Anon key moved to "done well" and the scanner appendix. 16 findings, all valid or accepted residuals; three accepted residuals rated Medium instead of Low. Copy predates the V37 fix, so V37 was reported again |

The bench is easy for current models: both baselines found nearly every textbook flaw. It measures report quality and discipline more than detection. A harder bench (subtle flaws diluted in mostly correct code) is planned.
