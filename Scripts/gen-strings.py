#!/usr/bin/env python3
"""Builds OmniCore's Localizable.xcstrings from the L10n accessor files.

The accessors (OmniKit/Sources/OmniCore/Strings/*.swift) are the source of
the English text; this script writes the String Catalog translators use.
Existing translations for other languages in the catalog are kept.

Usage: gen-strings.py [--check]   (--check: exit 1 if the catalog is stale)
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRINGS = os.path.join(ROOT, "OmniKit/Sources/OmniCore/Strings")
CATALOG = os.path.join(ROOT, "OmniKit/Sources/OmniCore/Resources/Localizable.xcstrings")

LIT = r'"((?:[^"\\]|\\.)*)"'
TR = re.compile(r'\b(?:tr|format)\(\s*' + LIT + r'\s*,\s*' + LIT, re.S)
PLURAL = re.compile(r'\bplural\(\s*' + LIT + r'\s*,\s*one:\s*' + LIT + r'\s*,\s*other:\s*' + LIT, re.S)

def unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c != "\\":
            out.append(c); i += 1; continue
        n = s[i + 1]
        if n == "u" and s[i + 2] == "{":
            end = s.index("}", i)
            out.append(chr(int(s[i + 3:end], 16))); i = end + 1; continue
        out.append({"n": "\n", "t": "\t", "0": "\0", "\\": "\\", '"': '"', "'": "'"}[n]); i += 2
    return "".join(out)

def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}

def collect():
    entries, problems = {}, []
    for name in sorted(os.listdir(STRINGS)):
        if not name.endswith(".swift") or name == "L10n.swift":
            continue
        text = open(os.path.join(STRINGS, name), encoding="utf-8").read()
        found = [(m.start(), m.group(1), {"en": unit(unescape(m.group(2)))}) for m in TR.finditer(text)]
        found += [(m.start(), m.group(1), {"en": {"variations": {"plural": {
            "one": unit(unescape(m.group(2))), "other": unit(unescape(m.group(3)))}}}}) for m in PLURAL.finditer(text)]
        for _, key, loc in sorted(found):
            if key in entries and entries[key] != loc:
                problems.append(f"{name}: key '{key}' defined twice with different text")
            entries[key] = loc
    entries["meta.catalogLoaded"] = {"en": unit("yes")}
    return entries, problems

def build(entries, old):
    strings = {}
    for key in sorted(entries):
        locs = dict(old.get("strings", {}).get(key, {}).get("localizations", {}))
        locs.update(entries[key])  # English always from source; other languages kept
        strings[key] = {"extractionState": "manual", "localizations": locs}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}

def main():
    entries, problems = collect()
    if problems:
        print("\n".join(problems)); sys.exit(1)
    old = json.load(open(CATALOG, encoding="utf-8")) if os.path.exists(CATALOG) else {}
    text = json.dumps(build(entries, old), ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    current = open(CATALOG, encoding="utf-8").read() if os.path.exists(CATALOG) else ""
    if "--check" in sys.argv:
        if text != current:
            print("Localizable.xcstrings is out of date: run `make strings`."); sys.exit(1)
        print(f"String catalog up to date ({len(entries)} keys)."); return
    if text != current:
        open(CATALOG, "w", encoding="utf-8").write(text)
    print(f"Wrote {len(entries)} keys to Localizable.xcstrings")

main()
