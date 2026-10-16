# GitHub Actions and CI

CI holds the keys to the kingdom: write tokens, deployment credentials, package publishing rights. A workflow that runs attacker-controlled code with those keys hands over the project.

Sources: GitHub Docs "Security hardening for GitHub Actions", OpenSSF Scorecard (Token-Permissions, Pinned-Dependencies, Dangerous-Workflow), zizmor audit documentation.

## Checklist

| Check | Flaw | Expected |
|---|---|---|
| Dangerous triggers | `pull_request_target` or `workflow_run` that checks out and runs the PR's code (`ref: ${{ github.event.pull_request.head.sha }}`, `npm install`, `make`, scripts from the PR) | `pull_request` for untrusted code; `pull_request_target` only for jobs that never run PR code |
| Script injection | `${{ github.event.* }}` values controlled by outsiders (PR title and body, issue title and body, comment body, branch names via `github.head_ref`, commit messages) written directly inside `run:` | Pass them through `env:` and use the shell variable, quoted |
| Token permissions | `permissions: write-all` or no `permissions` key (defaults may be broad) | Top-level `permissions: contents: read`; widen per job only where needed |
| Action pinning | Third-party actions referenced by tag or branch (`@v4`, `@main`) | Full commit SHA with the version in a comment; first-party actions at least by tag, ideally by SHA |
| Credential persistence | `actions/checkout` leaves the token in `.git/config` for later steps and artifacts | `persist-credentials: false` unless a later step pushes |
| Secrets exposure | Secrets passed to steps that run untrusted code; secrets echoed; secrets in artifacts | Secrets only in trusted jobs, scoped per environment, never printed |
| Self-hosted runners | Self-hosted runners used by public repositories | GitHub-hosted runners for public projects, or ephemeral isolated runners |
| Deployment | Deploy jobs reachable from PRs; no environment protection | Deploy from protected branches with environment reviewers |
| Caches and artifacts | Cache poisoning across trust levels; artifacts from untrusted runs consumed by privileged workflows | Separate cache keys; verify artifacts before use |

## How to verify

Write who can trigger it and what they get: "Any GitHub user opens a PR whose `package.json` has a `postinstall` script; `pull_request_target` checks out that code and runs `npm install` with `DEPLOY_TOKEN` in the environment and a write-all token: the attacker exfiltrates both". That chain is Critical on a public repository.

Remember that workflow files must be valid YAML: a workflow that fails to parse never runs, so its checks give no protection.
