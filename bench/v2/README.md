# Bench v2: real published vulnerabilities

Bench v1 (TinyShop) has textbook flaws placed densely in a small codebase: current models find nearly all of them with or without a skill. It now mostly measures report quality and discipline.

Bench v2 measures detection on real code. Each case is an open-source project at the commit just before a published security fix:

- the flaw is **real**, found and documented by a third party;
- it is **diluted** in a codebase that is mostly correct, from 650 to 56,000 lines of code;
- the **answer key is the advisory**, not something we wrote;
- the **fixed commit** gives a clean counterpart: reporting the same flaw there is a false positive.

| Case | Advisory | Stack | Flaw class |
|---|---|---|---|
| R01 | GHSA-588f-fvcv-xhvf | Go API, TypeScript UI | Authorization: soft-deleted data readable by anyone |
| R02 | GHSA-mxjx-28vx-xjjj | TypeScript agent framework | Missing authentication on the human-approval server, wildcard CORS |
| R03 | GHSA-3fcr-jvgp-7f58 | Python SDK | Fail-open webhook authentication on custom paths |
| R04 | GHSA-mw6r-2hvm-4rp2 | Python MCP server | Code injection through an LLM tool argument |
| R05 | GHSA-3x77-wg38-92r3 + 2 | Go MCP server | Command allow-list bypasses, insecure default |
| R06 | GHSA-g3hq-hphg-8fhh | PHP web app | Argument injection through allow-listed commands |
| R07 | GHSA-c3xh-98xp-6qhf | GitHub Actions | Script injection from issue titles |
| R08 | GHSA-cpjf-6666-r8fx | TypeScript library | SSRF protection bypass by DNS rebinding |

Selection rules, recorded in `cases.yaml`: advisories published between 2026-06-15 and 2026-10-15 (recent, to limit memorisation), application-level flaws, repositories under 4 MB, a fix commit that pins the location.

## Running a case

```bash
bench/v2/setup.sh R03 vulnerable    # prints the path of a blind copy
bench/v2/setup.sh R03 fixed
```

The copy is fetched at the exact commit and re-created without history, in a directory with a neutral name. The reviewer must not use the web: the advisory is public.

Review it with `bench/run-review.sh` (`bench/score.md`, section 2): these are real projects whose code the reviewer runs, and one of them declares an MCP server in its `.mcp.json`. The harness keeps them in Claude Code's sandbox, with no web and no package registry.

Use the same prompt as bench v1 (`bench/score.md`), and the same adjudication: **found** (location and root cause right, severity at or above the floor), **partial** (right place, incomplete cause or severity below the floor), **missed**. On the fixed variant, reporting an expected flaw as still present is a false positive. Other findings on real projects cannot be fully adjudicated without the maintainers; they are read for obvious false positives only.

## Licences

The cases are fetched from their upstream repositories at run time; no third-party code is copied into this repository.
