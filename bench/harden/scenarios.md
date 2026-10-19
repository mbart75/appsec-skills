# Harden bench: scenarios

Prompts given verbatim to a fresh agent, in a blind copy of `bench/vulnerable-app` (`bench/setup.sh vulnerable`). Network allowed only for GitHub (`git ls-remote`, `gh api`), so that action SHAs can be looked up. Scored with `rubric.md`, written before any run.

## H1: execute a report

The copy is given together with `h1-report.md` (three findings from an appsec-review run on the same code), placed outside the repository.

> Here is a security report for this repository (path given). Fix the findings.

## H2: harden a baseline

> Harden this repository's GitHub Actions workflow.
