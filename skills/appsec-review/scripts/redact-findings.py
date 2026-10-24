#!/usr/bin/env python3
"""Removes secret values from scanner output before it is written to disk.

    trufflehog git ... --json | python3 -I redact-findings.py trufflehog > trufflehog.json
    bandit -r ... -f json      | python3 -I redact-findings.py bandit     > bandit.json

Neither tool can redact its own JSON. TruffleHog puts the secret in Raw, RawV2 and
SecretParts (and StructuredData for some detectors); Bandit copies the offending lines into
`code` and the value of a hardcoded password into its message. Those fields become
[REDACTED], and every value found in them is also removed from any other field.
The file, line, commit and detector stay: the reviewer reads the value in the code.

Fails closed: input that cannot be parsed is not copied. Exit code 1 if anything was dropped.
Standard library only.
"""
import json
import re
import sys

MARK = "[REDACTED]"
# Shorter values would match ordinary text; the fields that hold them are replaced whole anyway.
MIN_SCRUB = 4
PASSWORD_TESTS = {"B105", "B106", "B107"}
PASSWORD_TEXT = re.compile(r"^(Possible hardcoded password: )'(.*)'$", re.DOTALL)


def scrub(value, secrets):
    """Replaces every known secret inside strings, keys included, recursively."""
    if isinstance(value, str):
        for s in secrets:
            value = value.replace(s, MARK)
        return value
    if isinstance(value, list):
        return [scrub(v, secrets) for v in value]
    if isinstance(value, dict):
        return {scrub(k, secrets): scrub(v, secrets) for k, v in value.items()}
    return value


def ordered(secrets):
    # Longest first, so a secret that contains another is replaced whole.
    return sorted({s for s in secrets if isinstance(s, str) and len(s) >= MIN_SCRUB}, key=len, reverse=True)


def trufflehog_finding(finding):
    secrets = [finding.get("Raw"), finding.get("RawV2")]
    for key in ("Raw", "RawV2"):
        if finding.get(key):
            finding[key] = MARK
    parts = finding.get("SecretParts")
    if isinstance(parts, dict):
        secrets += parts.values()
        finding["SecretParts"] = {k: MARK for k in parts}
    if finding.get("StructuredData"):
        finding["StructuredData"] = MARK
    return scrub(finding, ordered(secrets))


def trufflehog(stdin, stdout):
    dropped = 0
    for line in stdin:
        if not line.strip():
            continue
        try:
            finding = json.loads(line)
        except ValueError:
            dropped += 1
            continue
        if not isinstance(finding, dict):
            dropped += 1
            continue
        stdout.write(json.dumps(trufflehog_finding(finding)) + "\n")
    if dropped:
        print(f"redact-findings: {dropped} line(s) of TruffleHog output were not JSON and were dropped", file=sys.stderr)
    return 1 if dropped else 0


def bandit(stdin, stdout):
    try:
        report = json.load(stdin)
    except ValueError:
        print("redact-findings: Bandit output was not JSON and was dropped", file=sys.stderr)
        return 1
    secrets = []
    for result in report.get("results", []) if isinstance(report, dict) else []:
        if "code" in result:
            result["code"] = MARK
        text = result.get("issue_text")
        if result.get("test_id") in PASSWORD_TESTS and isinstance(text, str):
            match = PASSWORD_TEXT.match(text)
            if match:
                secrets.append(match.group(2))
            result["issue_text"] = "Possible hardcoded password: " + MARK
    json.dump(scrub(report, ordered(secrets)), stdout, indent=2)
    stdout.write("\n")
    return 0


def main():
    tools = {"trufflehog": trufflehog, "bandit": bandit}
    if len(sys.argv) != 2 or sys.argv[1] not in tools:
        print("usage: python3 -I redact-findings.py trufflehog|bandit < output > redacted", file=sys.stderr)
        return 2
    return tools[sys.argv[1]](sys.stdin, sys.stdout)


if __name__ == "__main__":
    sys.exit(main())
