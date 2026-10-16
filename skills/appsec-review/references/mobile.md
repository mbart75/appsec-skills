# Mobile applications (iOS, Android, cross-platform)

Sources: OWASP MASVS 2 and MASTG, Apple Platform Security guide, Android security best practices.

The binary is in the attacker's hands: anything inside it can be extracted, and any check done only on the device can be bypassed. The backend API must enforce everything (`api.md`, `access-control.md`).

| MASVS area | Check | Flaw |
|---|---|---|
| STORAGE | Tokens and personal data in Keychain (iOS) or Keystore-backed encrypted storage (Android) | Tokens in `UserDefaults`, `SharedPreferences`, `AsyncStorage`, SQLite in clear, logs, screenshots in the app switcher |
| CRYPTO | Platform crypto APIs, keys in secure hardware where possible | Hard-coded keys, home-made crypto |
| AUTH | Session handled by the backend; biometrics unlock a Keychain item rather than a local boolean | "Logged in" flag stored locally; biometric check that only returns true/false |
| NETWORK | TLS everywhere; App Transport Security not disabled; no cleartext traffic allowed in Android network security config | `NSAllowsArbitraryLoads`, `usesCleartextTraffic="true"`, custom trust managers accepting all certificates |
| PLATFORM | Deep links and app links validate their parameters; WebViews do not expose native bridges to remote content; exported Android components protected | `javascriptInterface` on a WebView loading remote URLs; exported activities performing privileged actions |
| CODE | Dependencies current; no debug builds or logging in release | `debuggable=true`, verbose logs with tokens |
| RESILIENCE | Optional: obfuscation, jailbreak/root detection, only as friction, never as the security control | Security relying on the app not being modified |
| PRIVACY | Only necessary permissions and data; tracking declared | Location, contacts or advertising identifiers collected without need |

Secrets in the binary: API keys for paid services, admin keys and signing secrets must stay on a server. A key that must ship in the app must be one designed to be public and restricted (by bundle id, package signature, API restrictions).

Store requirements to check before release: in-app account deletion (Apple App Store guideline 5.1.1(v)), privacy declarations (App Store privacy details, Google Play Data safety form), App Tracking Transparency when tracking across apps.
