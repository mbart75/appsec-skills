# Test bench

> **Deliberately vulnerable code.** `vulnerable-app/` exists to be attacked by reviews. Never deploy it, never copy code from it. All secrets in it are fake.

A skill that *seems* good is not the same as a skill *proven* good. This bench measures it: how many seeded flaws a review finds (recall) and how much it invents (precision).

## Contents

| Path | Role |
|---|---|
| `vulnerable-app/` | TinyShop, a small multi-stack shop with 37 seeded flaws: Express API, Supabase schema, vanilla JS front-end, Python worker, Terraform, PowerShell, bash, GitHub Actions, an LLM support bot with a tool |
| `secure-app/` | The same application with every flaw fixed, plus a few traps: safe code that naive reviews or scanners flag |
| `expected.yaml` | The answer key. Never shown to the reviewing agent |
| `check-key.py` | Verifies the key still matches the code. Run it after any edit |
| `setup.sh` | Builds a blind scratch copy of one variant, outside this repository, with its own git history |
| `score.md` | How to run a review and score it |
| `v2/` | Eight real advisories, reviewed at the commit before and after their fix |
| `live-target/` | Reviewing a deployed app without its source: planning and recording authorized tests |
| `deps/` | Triage of known vulnerabilities in dependencies by exploitation (KEV, EPSS) and reachability |
| `threat-model/`, `harden/`, `compliance-fr/` | Scenarios and rubrics for the other three skills |

## Adding a flaw

1. Add the vulnerable code to `vulnerable-app/` and its fix to `secure-app/`.
2. Add an entry to `expected.yaml` with an `anchor` copied from the vulnerable line.
3. Run `python3 bench/check-key.py`: it must report 0 problems.
4. Keep the code free of hints: no comment may point at the flaw.

## Coverage

Each seeded flaw maps to a reference checklist of `appsec-review`. Mobile and macOS references are not covered by this version of the bench.
