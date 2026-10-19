# Dependency bench: known vulnerabilities, exploitation and reachability

> **Deliberately outdated dependencies.** `app/` pins versions with published vulnerabilities. Never deploy it, never copy its versions.

Ledgerly is a small fictional invoicing tool: a Node.js web app and a Java report service. Its code has no seeded logic flaw on purpose: the bench measures how a review **triages known vulnerabilities in dependencies**, not how it finds code flaws.

| Dependency | Where | Reachable? | Known exploited (CISA KEV)? |
|---|---|---|---|
| `log4j-core` 2.14.1 | `report-service/pom.xml` | Yes: the browser's `User-Agent` is forwarded by the web app's proxy and logged | Yes (CVE-2021-44228, CVE-2021-45046) |
| jQuery 3.4.1 | vendored file in `web/public/vendor/`, in no manifest | Yes: sanitized user HTML is passed to `.html()` | Yes (CVE-2020-11023) |
| `ejs` 3.1.6 | `web/package-lock.json` | Yes: query parameters are spread into the render options | No |
| `lodash` 4.17.15 | `web/package-lock.json` | No: only `_.get` is used | No, and several of its CVEs have a high EPSS |

`setup.sh` builds a blind copy. `scenario.md` holds the prompt and the rubric, written before any run. `expected.yaml` is the answer key.
