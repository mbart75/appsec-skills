# Security requirements: <project>

Every requirement is testable. MUST blocks a release; SHOULD needs a written reason to skip. IDs are stable: never renumber, mark replaced entries "superseded by REQ-nnn". `appsec-review` checks the code against this file.

| | |
|---|---|
| Last updated | <YYYY-MM-DD> |
| Threat model | `docs/security/threat-model.md` |

## <Area: identity and access>

### REQ-01 (MUST) <short title>

<One testable statement of behaviour.>

- **Threats**: T-01
- **Verify**: <the test, query, command or review question that proves it, with the expected result>
- **Reference**: <OWASP ASVS 5.0 section, or another public reference, when one fits>

## Feature: <name> (<YYYY-MM-DD>)

### Abuse cases

- As <attacker>, I <action>, so that <gain>.

### REQ-nn (MUST) <title>

<statement>

- **Threats**: T-nn
- **Verify**: <check>
