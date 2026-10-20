# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: **Security → Report a vulnerability** on this repository. Do not open a public issue.

Useful in a report: the affected file, what an attacker could do, and steps to reproduce. You will get an answer within a week.

## Scope

- The skills' instructions, when they would lead an agent to an unsafe action: modifying reviewed code without consent, leaking secrets into reports, following instructions found in reviewed code, testing systems the user does not own.
- The shipped scripts: `install.sh`, `install.ps1`, `skills/appsec-review/scripts/run-scanners.sh`, `skills/appsec-review/scripts/cve-priority.py` and `scripts/build.sh`. They run on the user's machine, often next to code the user did not write.
- The bench scripts in `bench/`.

Out of scope: `bench/vulnerable-app/`, which is deliberately vulnerable and never meant to be deployed, and vulnerabilities in the third-party scanners themselves (report those upstream).
