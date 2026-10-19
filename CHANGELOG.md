# Changelog

## 0.7.1 (2026-10-20)

- `supabase-rls-probes.md`: the public key is sent in `apikey` only (newer `sb_publishable_` keys are not JWTs); the setup warns when the session has expired and says that a `401` on a session request is a probe error, not "blocked"; probe D stops with a probe error when the account already holds the attempted value, instead of reporting a false escalation.
- Bench `bench/batch/` (Receiptly, a batch job where one bad file blocks every later run): the model already finds it 3/3 with 0.7.0. A candidate rule did not make bench v1 find V37, the same class masked by command-execution flaws in the same function, so it was not adopted. Details in `bench/batch/results.md`.
- Cross-model check with Codex (GPT-6.1, 0.7.0 skills): live-target L2 (plan from a URL) 9/9; L3 (RLS probes) 5/7, no role probe and manual instead of automatic undo; the dependency bench run was cut by the Codex usage limit before the report, after `cve-priority.py` had run inside the Codex sandbox. Semgrep cannot run in that sandbox (it writes to `~/.semgrep`).

## 0.7.0 (2026-10-19)

- `appsec-harden`: **Supabase RLS, safe baseline** in `references/baselines.md`, as changes with their checks: RLS enabled and forced; default deny with one policy per operation and role; ownership with `using` and `with check` on `auth.uid()`; privileged fields protected by a trigger or column privileges, with an explicit refusal rather than a `200` that ignores the field; profiles created server-side; access to another account's data only through a link row the data owner activates; hardened `security definer` functions (`search_path`, `auth.uid()`, minimal `execute`); `security_invoker` views; `aal2` for sensitive roles; `octet_length` limits on client-written columns; Auth settings (password length, leaked-password protection, dedicated SMTP). Ends with the verify loop: replay `appsec-review/references/supabase-rls-probes.md`, then `appsec-review` in verify mode.
- `appsec-harden` description and input list name database access rules (Supabase RLS), so the skill triggers on that request.
- Regression check on harden bench H2 (harden a CI workflow): 8/8, both action SHAs verified against their tags, unverifiable third-party action replaced and flagged.

## 0.6.0 (2026-10-19)

- `appsec-review`: `references/supabase-rls.md`, what to verify in Supabase policies, each item with the read-only query that answers it: RLS enabled on every exposed table; ownership tied to `auth.uid()`; `with check` pinning the owner on insert and update; upserts covered on both sides; permissive policies combined with OR; privileged columns (`role`, `status`) not writable by the user; no authorization on user-editable metadata; relation rows created by the party who gives access; `security definer` functions (fixed `search_path`, identity from `auth.uid()`, minimal return, execute grants); views with `security_invoker`; `aal2` for sensitive roles; size and shape limits on JSON and text columns. Linked from `access-control.md`, `live-target.md` (phase 3), `supabase-rls-probes.md` and the skill's reference table; fixes go to `appsec-harden`, live confirmation to `supabase-rls-probes.md`.
- Bench `bench/deps/`: dependency manifests stored as `*.fixture` so that GitHub's dependency graph raises no alerts for these deliberately outdated versions; `setup.sh` restores their names in the blind copy.
- Regression check on bench v1: 36/37 (V37 missed, as in every version), no false positive, no secret leaked; the report names the skill version from `metadata.version`.

## 0.5.0 (2026-10-19)

- `appsec-review`: `references/supabase-rls-probes.md`, four console probes for the authorized-tests phase on a Supabase back end, run by a person from test accounts: read reach per table (session versus public key, counts only), another account's rows (filtered on a victim that holds data), a write that must be refused (undone by primary key, with the number of rows removed reported) and a protected field (judged on the returned row, restored if it changed). Linked from `live-target.md` and the skill's reference table. Generic placeholders only.
- `live-target.md`: neutral examples for the victim and unrelated accounts.
- Every `SKILL.md` declares its version in `metadata.version`, so reports can name it (an allowed frontmatter key for Codex and Claude Code).
- Bench `bench/live-target/` L3 (write the probes for a tester), rubric before runs, scored blind by a separate agent. Haiku 5.5: 0.4.0 scored 6, 4, 5 out of 7; with the probes reference 6, 7, 7. Common weak spots across all runs, left as known limits: a refused write probed with `return=representation` is not conclusive on its own (the policy export decides), and the role probe does not check that the account already holds the target value.

## 0.4.0 (2026-10-19)

- `appsec-review`: **known vulnerabilities ranked by real-world exploitation**. New `scripts/cve-priority.py` (standard library only), run by `run-scanners.sh` after OSV-Scanner: adds to each advisory whether it is in the CISA KEV catalog and its FIRST EPSS score, known exploited first, in `cve-priority.md`. `--package ECOSYSTEM:NAME@VERSION` covers libraries vendored outside any manifest. Only CVE identifiers (and, for `--package`, a package name and version) leave the machine; `--offline` disables it.
- Triage rules in `references/secrets-supply-chain.md`: inventory what ships, including vendored files; check reachability per advisory; reachable and known exploited is never below High and comes first; not reachable is Low at most whatever its CVSS or EPSS; hardening you cannot see does not lower a rating. The report template gains a *Known vulnerability* line (CVE, KEV, EPSS with date, fixed and recommended versions). The live-target reference checks the versions of shipped libraries; pre-launch item 16 now names KEV.
- Bench `bench/deps/` (Ledgerly: Node.js and Java, log4j 2.14.1, vendored jQuery 3.4.1, ejs 3.1.6, lodash 4.17.15), rubric before runs. Haiku 5.5: 3.3/9 on average → 9/9 on three runs. Details in `bench/deps/results.md`. Regression check on bench v1: 36/37 again, no false positive, no secret leaked.

## 0.3.0 (2026-10-19)

- `appsec-review`: **live targets**. A deployed application reviewed without its source, or tested while running, follows `references/live-target.md`: passive look first, the owner's written authorization with an explicit scope, test accounts created by a person, probes that can fail (a victim account holding data, an unrelated account per role), count-only reads, undone writes, a reading table for status codes (a `400` is a probe error, an empty `0` is inconclusive, a write is judged by the returned row). The report template gains `Authorization` and `Testing` rows, a test log and a list of test artefacts to remove; the verdict says what to do now when real users are already exposed.
- Bench `bench/live-target/`: two scenarios and their rubric. Haiku 5.5: L1 (update a report with test results) 10/11 on average → 11/11; L2 (plan from a URL only) 5/9 → 8.7/9. Details in `bench/live-target/results.md`. Regression check on bench v1: 36/37, no false positive.
- Bench compliance F2 (religion and health data inferred from diet options, health-data hosting): 5/5 on three runs with the current skill, so no change was made.

## 0.2.1 (2026-10-19)

- Interactive installers: `install.sh` (macOS, Linux) and `install.ps1` (Windows). They detect the agents present, let the user choose, show the plan, and only touch `appsec-*` folders. Copy mode by default, link mode from a clone, uninstall and dry-run options.
- Release zip unpacks into one folder with the skills and both installers; `SHA256SUMS` published with each release.

## 0.2.0 (2026-10-19)

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
| 2026-10-19 | appsec-review 0.4.0 (KEV and EPSS triage) | Claude Haiku 5.5 | vulnerable | 36/37 | n/a | 0 | Only V37 missed again; a few minor valid extras folded into existing findings; no lockfile in TinyShop, so the dependency finding says no version could be checked |
| 2026-10-19 | appsec-review 0.3.0 (live-target reference) | Claude Haiku 5.5 | vulnerable | 36/37 | n/a | 0 | Regression check after the live-target change: only V37 missed (worker loop without error handling); one accepted Low residual; no secret leaked; `Authorization` and `Testing` rows filled "not applicable" |
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
