#!/bin/bash
# Fails if user-facing text is written as a literal outside the L10n accessors
# (OmniKit/Sources/OmniCore/Strings), or if the String Catalog is stale.
# A literal without letters ("•", "\(x) %") is allowed, as is a line ending
# in `// l10n-ignore` (for symbols such as key glyphs).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/gen-strings.py --check
[ "${1:-}" = "--catalog-only" ] && exit 0
python3 - <<'PY'
import os, re, sys
PATTERN = re.compile(
    r'(?:\bText|\bButton|\bToggle|\bLabel|\bSection|\bPicker|\bMenu|\bTextField|\bLabeledContent|'
    r'\.help|HUD\.show|confirmationDialog|\.alert|navigationTitle|ActionMenuItem|NSMenuItem|'
    r'accessibilityLabel|SecureField|Link)\(\s*"((?:[^"\\]|\\.)*)"'
    r'|\b(?:title|subtitle|displayName|summary|messageText|informativeText|toolTip|placeholder|explanation)\s*[:=]\s*"((?:[^"\\]|\\.)*)"')
roots = ["App", "OmniKit/Sources"]
skip = os.path.join("OmniKit", "Sources", "OmniCore", "Strings")
bad = []
for root in roots:
    for dirpath, _, files in os.walk(root):
        if dirpath.startswith(skip):
            continue
        for name in files:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(dirpath, name)
            for number, line in enumerate(open(path, encoding="utf-8"), 1):
                if "l10n-ignore" in line or line.lstrip().startswith("//"):
                    continue
                for match in PATTERN.finditer(line):
                    literal = match.group(1) if match.group(1) is not None else match.group(2)
                    if re.search(r"[A-Za-z]", re.sub(r"\\\([^)]*\)", "", literal)):
                        bad.append(f"{path}:{number}: user-facing literal \"{literal[:60]}\" (move it to L10n)")
if bad:
    print("\n".join(bad))
    print(f"{len(bad)} user-facing string literal(s) outside L10n.")
    sys.exit(1)
print("No user-facing string literals outside L10n.")
PY
