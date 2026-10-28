#!/usr/bin/env python3
"""Checks that every anchor of expected.yaml still points at the vulnerable code.

Run after any edit to the bench. Fails if an anchor is missing from
vulnerable-app (the key would be wrong) or still present in secure-app
(the fix would be incomplete). An "absent" anchor is a missing file: it must be
missing from vulnerable-app and present in secure-app. Standard library only.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1].replace("''", "'")
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return value


def entries(text: str):
    flaws = text.split("secure_app_traps:")[0]
    for block in re.split(r"\n  - id: ", flaws)[1:]:
        fields = {"id": block.splitlines()[0].strip()}
        for line in block.splitlines()[1:]:
            m = re.match(r"\s{4}(\w+): (.*)", line)
            if m:
                fields[m.group(1)] = unquote(m.group(2))
        yield fields


def main() -> int:
    errors = 0
    flaws = list(entries((HERE / "expected.yaml").read_text()))
    for flaw in flaws:
        if flaw["anchor"] == "history":
            continue
        if flaw["anchor"] == "absent":
            if (HERE / "vulnerable-app" / flaw["file"]).exists():
                print(f"{flaw['id']}: vulnerable-app/{flaw['file']} exists, the key says it is missing")
                errors += 1
            if not (HERE / "secure-app" / flaw["file"]).exists():
                print(f"{flaw['id']}: secure-app/{flaw['file']} is missing (the fix would be incomplete)")
                errors += 1
            continue
        vulnerable = HERE / "vulnerable-app" / flaw["file"]
        secure = HERE / "secure-app" / flaw["file"]
        if flaw["anchor"] not in vulnerable.read_text():
            print(f"{flaw['id']}: anchor not found in vulnerable-app/{flaw['file']}")
            errors += 1
        if secure.exists() and flaw["anchor"] in secure.read_text() and flaw.get("same_in_secure") != "true":
            print(f"{flaw['id']}: anchor still present in secure-app/{flaw['file']}")
            errors += 1
    ids = [f["id"] for f in flaws]
    if len(ids) != len(set(ids)):
        print("duplicate ids")
        errors += 1
    print(f"{len(flaws)} flaws checked, {errors} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
