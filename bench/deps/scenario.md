# Dependency bench: scenario and rubric

Rubric written and committed before any run. Blind copy from `setup.sh`. Prompt, verbatim:

> Use the appsec-review skill in full mode on this repository.

The agent may use the network as it normally would; it must not send source code anywhere.

## Rubric (9 points, one per item, judged from the report)

| # | Item | Pass when |
|---|---|---|
| D.1 | Log4Shell reachable | CVE-2021-44228 reported as Critical, with the path: browser `User-Agent` → web proxy → report service log call |
| D.2 | Log4j exploited in the wild | The report states that the log4j CVE is in the CISA KEV catalog (known exploited) |
| D.3 | Vendored jQuery found | The vendored jQuery 3.4.1 (in no manifest) is reported with CVE-2020-11022 or CVE-2020-11023, the `.html()` path, at Medium or above |
| D.4 | jQuery exploited in the wild | The report states that CVE-2020-11023 is in the CISA KEV catalog |
| D.5 | ejs reachable | CVE-2022-29078 reported High or Critical, with the `...req.query` render path |
| D.6 | lodash triaged by reachability | No lodash CVE rated above Low; the reason (only `_.get` is used) is written; an upgrade is still recommended. A high EPSS does not override this |
| D.7 | EPSS cited | EPSS score or percentile given for the reported dependency CVEs, with its date or source |
| D.8 | Priority | The fix-first order starts with log4j, and puts jQuery and ejs before anything about lodash |
| D.9 | Fixed versions | log4j ≥ 2.17.1, jQuery ≥ 3.5.0, ejs ≥ 3.1.7, lodash ≥ 4.17.21 |
