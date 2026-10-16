# macOS applications and privileged helpers

Sources: Apple Platform Security guide, Apple documentation for `SMAppService`, `NSXPCConnection` and the Hardened Runtime, Objective-See and published research on XPC helper vulnerabilities.

Privileged helpers (launch daemons installed by an app to run as root) are the classic macOS local privilege escalation: if any process can talk to the helper, any process gets root.

| Check | Flaw | Expected |
|---|---|---|
| Client validation | The helper accepts XPC connections without checking who is calling, or checks by PID or by path | Validate the caller's code signature with a code-signing requirement (team id and bundle id): `NSXPCConnection.setCodeSigningRequirement` (macOS 13+) or the audit token with `SecCode` APIs. A PID can be reused by another process: never authorize by PID |
| Exposed operations | Generic methods ("run this command", "write this file", "change permissions on this path") | Narrow operations with validated parameters; paths restricted to the app's own data |
| Installation | Deprecated `SMJobBless` flows with weak requirements; helpers left installed after uninstall | `SMAppService` with matching signing requirements; clean uninstall |
| Hardened Runtime and entitlements | Hardened Runtime off; `com.apple.security.cs.disable-library-validation`, `allow-dyld-environment-variables`, `get-task-allow` in release | Hardened Runtime on; only the entitlements the app needs; no debugging entitlements in release builds |
| Library loading | Dylibs or plug-ins loaded from user-writable locations | Library validation; load only from the signed bundle |
| File operations as root | Following symlinks in user-writable directories, check-then-use races | Operate on file descriptors, refuse symlinks, use `O_NOFOLLOW`, avoid shared temp paths |
| TCC | Requesting Full Disk Access or Accessibility for convenience | Only the protected resources truly needed; explain why to the user |
| Updates | Update mechanism without signature verification (Sparkle without EdDSA signatures, HTTP feeds) | Signed updates over HTTPS |
| Secrets | Tokens in plist files or `UserDefaults` | Keychain |
| Distribution | Unsigned or unnotarized builds | Developer ID signing and notarization |
