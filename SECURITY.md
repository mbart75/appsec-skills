# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: **Security → Report a vulnerability** on this repository. Do not open a public issue.

Useful in a report: the affected file, what an attacker could do, and steps to reproduce. You will get an answer within a week.

## Scope

- The skills' instructions, when they would lead an agent to an unsafe action: modifying reviewed code without consent, leaking secrets into reports, following instructions found in reviewed code, testing systems the user does not own.
- The shipped scripts: `install.sh`, `install.ps1`, `skills/appsec-review/scripts/run-scanners.sh` with its `gitleaks.toml`, `skills/appsec-review/scripts/cve-priority.py`, `skills/appsec-review/scripts/redact-findings.py` and `scripts/build.sh`. They run on the user's machine, often next to code the user did not write.
- The bench scripts in `bench/`.

Out of scope:

- Deliberately flawed bench material, never meant to be deployed: `bench/vulnerable-app/`, the outdated dependencies of `bench/deps/app/`, the batch job of `bench/batch/app/`, the fake secrets throughout `bench/`, and the residual weaknesses of `bench/secure-app/` listed as accepted in `bench/expected.yaml`. A real flaw in `bench/secure-app/` that is not listed there is in scope: it is a gap in the bench.
- The throwaway repositories that `tests/` and the bench `setup.sh` scripts build on purpose (hostile scanner settings, fake secrets).
- The third-party projects that bench v2 fetches at run time, and the third-party scanners themselves: report those upstream.
