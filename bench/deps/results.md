# Dependency bench: results

Claude Haiku 5.5, full mode, scanners installed, network allowed (never for source code), three blind copies per variant. Scored against `scenario.md`, committed before the first run. KEV and EPSS as of 2026-10-19.

| Item | 0.3.0 (runs 1, 2, 3) | 0.4.0 (runs 1, 2, 3) |
|---|---|---|
| D.1 Log4Shell Critical, path shown | pass, fail (rated High on a "maybe recent JDK"), pass | pass, pass, pass |
| D.2 log4j in KEV stated | fail, fail, fail | pass, pass, pass |
| D.3 vendored jQuery reported at Medium or above | fail (Low), pass, fail (praised the `.html()` call as "done well") | pass, pass, pass |
| D.4 jQuery CVE-2020-11023 in KEV stated | fail, fail, fail | pass, pass, pass |
| D.5 ejs High or Critical, path shown | pass, pass, pass | pass, pass, pass |
| D.6 lodash Low with the reachability reason | pass, pass, pass | pass, pass, pass |
| D.7 EPSS cited with its date | fail, fail, fail | pass, pass, pass |
| D.8 log4j first, jQuery and ejs before lodash | fail, fail, fail | pass, pass, pass |
| D.9 fixed versions | pass, fail (no lodash version), fail (no jQuery version) | pass, pass, pass |
| **Total (9)** | **4, 3, 3** | **9, 9, 9** |

Without the change, the model found the libraries and the code paths but never used exploitation data: KEV and EPSS were absent from every report, the ejs RCE always came first, and the known-exploited jQuery flaw was missed or rated Low twice. Reachability for lodash was already handled well.
