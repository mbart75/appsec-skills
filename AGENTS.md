# Instructions for AI agents

This repository contains security skills for AI coding agents.

## Using the skills

If your environment loads skills natively, install the folders under `skills/` in your skills directory (see `README.md`). Otherwise, when the user asks for one of the tasks below, read the matching `SKILL.md` and follow it, reading the reference files it points to as needed.

| The user asks to... | Read |
|---|---|
| Review code, a pull request or a repository for security; check if an app is safe to launch or to make public; review or test a deployed site without its code; verify fixes from a security report | `skills/appsec-review/SKILL.md` |
| Design security before building an app or a feature; write a threat model or security requirements | `skills/appsec-threat-model/SKILL.md` |
| Fix findings from a security report; harden CI, headers, cookies, repository hygiene | `skills/appsec-harden/SKILL.md` |
| Check French legal compliance of a site or app; draft mentions légales, privacy notice, CGV | `skills/appsec-compliance-fr/SKILL.md` |

## Working on this repository

- `bench/vulnerable-app/` is deliberately vulnerable test material. Never copy code from it, never "fix" it: its flaws are the answer key of the bench.
- After any change to a skill, run the bench (`bench/score.md`, `bench/v2/README.md`) and record the result in `CHANGELOG.md`.
- After editing `bench/`, run `python3 bench/check-key.py`.
- Shell scripts must pass `shellcheck`.
- Everything in this repository is public and in English. No personal data, no real secrets, no reports of real vulnerabilities in other projects that are not already public.
