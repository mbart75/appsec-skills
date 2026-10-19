# Changelog

## Unreleased

- `appsec-review`: first version. Modes `diff`, `full`, `pre-launch`, `verify`; report designed as a work order (stable IDs, "Done when", status, hand-off); scanner runner for 11 tools; 16 reference checklists.
- Test bench: TinyShop with 37 seeded flaws, its fixed counterpart with 7 traps, answer key and scoring procedure.

- `appsec-threat-model`: security by design, project and feature scopes; writes `docs/security/threat-model.md` and `requirements.md`.
- `appsec-harden`: applies fixes and baselines one proven commit at a time.
- `appsec-compliance-fr`: French legal checklist with sources and draft pages in French.
- `appsec-review`: low severity is not uncertainty (a defect only an operator can trigger is a Low finding, not an open question).

## Bench results: appsec-threat-model, appsec-harden, appsec-compliance-fr (2026-10-19)

Rubrics in `bench/threat-model/`, `bench/harden/` and `bench/compliance-fr/` were written and committed before the first run.

| Bench | No skill (Haiku 5.5) | Skill (Haiku 5.5) | Skill in Codex (GPT-6, low effort) |
|---|---|---|---|
| Threat model S1, new app | 13/17 | **17/17** | not run |
| Threat model S2, new feature | 10/12 | **12/12** | about 10.5/12 (codes not stored hashed) |
| Harden H1, execute a report | 7/8 | **8/8** | not run |
| Harden H2, harden CI | 7/8 | **8/8** (SHAs independently verified, zizmor 6 → 0) | not run |
| Compliance F1, launch in France | about 13.5/14 | about 13.5/14 | scope respected, cookies judged correctly |

What the skills changed:

- **Threat model**: without the skill, the analysis was good but stayed in the chat. With it, the documents land in the project, every requirement carries a Verify line, threats name the boundary they cross, and developer accounts (code host, hosting, database, registrar) get an MFA requirement. Existing weaknesses were kept out of the committed documents and pointed to `appsec-review`.
- **Harden**: without the skill, fixes were right but "verified by eye" when the runtime was missing, and an available scanner was not run. With it, each fix is proven with what is available (grep, parsing, scanners, a control run showing the scanner works) and a risky change needing a decision was left to a person.
- **Compliance**: the rubric was saturated by the model alone. The skill's measurable effect was scope: without it, the agent translated the interface, changed price display code and added comments in five code files; with it, only legal pages and a footer were added. This criterion was noticed after the baseline run, not in the rubric written beforehand.
- **Codex / GPT**: skills load natively from `~/.codex/skills/` and the report and document contracts were followed. On bench v1, `appsec-review` in Codex found 31 of 37 flaws (84%) at low reasoning effort; it parked operator-only defects in Open questions, which led to the rule above.

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
- **Fixed commits**: no expected flaw was reported again on the seven fixed commits reviewed. On several, the review reported something else in the same area (an unfixed sibling, residual weaknesses around the fix). Rechecked on each project's current main branch three days later: two had since been fixed upstream, one is a documented design choice, and one remains and is handled by coordinated disclosure (not described here). The first check of one of them was wrong, because a single matching line was read without its context: verifying a finding means reading the surrounding code.
- **What the skill adds** is therefore not more detection on these cases but the report itself (work order, verified findings, "Done when", statuses, verify mode), consistent redaction and scope discipline. A baseline without the skill on the fixed commits was not run, so finding residual issues there cannot be credited to the skill.

The v1 bench is easy for current models: both baselines found nearly every textbook flaw. It measures report quality and discipline more than detection. A harder bench (subtle flaws diluted in mostly correct code) is planned.
