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

### Bench v2 (real advisories), Claude Haiku 5.5, full mode, scanners installed, web disabled

Recall on the vulnerable commit. Floors from `bench/v2/cases.yaml` (R04 floor lowered to Medium after checking that no MCP tool calls the vulnerable function at that commit).

| Case | No skill | appsec-review v1 | appsec-review v3/v4 (current) | Current, on the fixed commit |
|---|---|---|---|---|
| R01 authorization, Go | found | not run | partial (right flaw, rated Low) | not reported; a related issue on deleted books reported |
| R02 missing auth, TypeScript, 56k lines | found | not run | found | not run (size) |
| R03 fail-open webhook auth, Python | found | not run | found | expected flaw not reported; one additional finding |
| R04 code injection, Python MCP | found (Medium, latent) | partial (open question) | found | not reported |
| R05 allow-list bypasses x3, Go MCP | 3/3 | 3/3 | 3/3 | not reported; one additional finding |
| R06 argument injection, PHP | found | partial (rated Low) | found | not reported as the original flaw; possible bypasses of the fix itself |
| R07 CI script injection | found | found | found | not reported; an unfixed sibling workflow reported |
| R08 SSRF via DNS rebinding, TypeScript | found | **missed** | found | not reported; one additional finding |
| **Total** | **8/8** | 3.5/6 run | **7.5/8** | **0 false positives** on 7 fixed commits |

What this shows, plainly:

- **Detection**: the model alone already found all eight real flaws. The first version of the skill did *worse* (3.5 out of 6): its anti-false-positive rules pushed the agent to under-report latent or library-level flaws and to under-rate control bypasses, and its SSRF guidance accepted a validate-then-resolve-again guard. Three rules were added from these failures (attack every existing control; exported APIs are entry points; a control bypass is at least Medium) and the SSRF checklist was completed. The current version is level with the model alone, not better. R08 was found after its reference was updated following the miss on that same case, so that result may be partly fitted to the bench.
- **Fixed commits**: no expected flaw was reported again on the seven fixed commits reviewed. On several, the review reported something else in the same area (an unfixed sibling, residual weaknesses around the fix). Where checked against the code, these were real. Findings that may concern unpublished issues in third-party projects are not described here; they are handled by coordinated disclosure.
- **What the skill adds** is therefore not more detection on these cases but the report itself (work order, verified findings, "Done when", statuses, verify mode), consistent redaction and scope discipline. A baseline without the skill on the fixed commits was not run, so finding residual issues there cannot be credited to the skill.

The v1 bench is easy for current models: both baselines found nearly every textbook flaw. It measures report quality and discipline more than detection. A harder bench (subtle flaws diluted in mostly correct code) is planned.
