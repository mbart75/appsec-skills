# Bash and shell scripts

Sources: ShellCheck wiki, Google Shell Style Guide, CWE-78 and CWE-95.

| Check | Flaw | Expected |
|---|---|---|
| `eval` and indirect execution | `eval` on arguments, environment values, file contents or command output; `bash -c "$var"`; `source` of user-writable files | Arrays for commands; no `eval` on anything an outsider can influence |
| Quoting | Unquoted `$var` and `$(...)`: word splitting and globbing turn data into extra arguments or file names | Quote every expansion: `"$var"`, `"${array[@]}"` |
| Destructive commands | `rm -rf $DIR/*` with `DIR` possibly empty or unset (becomes `rm -rf /*`) | `set -u`, `"${DIR:?}"`, and an allow-list of target paths after resolving `..` and symlinks |
| Path checks | `case "$path" in /safe/*)` on an unresolved path (`/safe/../../etc` matches) | Resolve first (`cd -- "$p" && pwd -P` or `realpath`), then compare to exact values |
| Option injection | File names starting with `-` passed to commands | `--` before file arguments, or `./` prefix |
| Temporary files | Fixed names in `/tmp`, predictable names (symlink attacks) | `mktemp`, restrictive `umask`, cleanup with `trap` |
| Error handling | Scripts continue after a failed step | `set -euo pipefail`, with care: a failing command substitution under `pipefail` can stop the script silently, so test guard conditions explicitly with clear messages |
| Secrets | Tokens in arguments (visible in `ps`), `set -x` printing secrets, secrets in history | Pass through environment or files with restricted permissions; no tracing around secrets |
| Downloads | `curl ... | sh`, unverified binaries | Pinned version plus checksum or signature check |
| Privilege | Whole script run with `sudo` when one command needs it | Minimal privileged steps |

Who controls the input decides the severity. An argument typed by the operator is low risk; a branch name, PR title or file name passed by CI from an outside contribution is attacker-controlled.
