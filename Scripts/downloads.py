#!/usr/bin/env python3
"""Prints how many times each GitHub release file of Tolio was downloaded."""
import json
import urllib.request

URL = "https://api.github.com/repos/keburius/tolio/releases"
with urllib.request.urlopen(URL, timeout=15) as response:
    releases = json.load(response)

total = 0
for release in releases:
    print(release["tag_name"])
    for asset in release["assets"]:
        print(f"  {asset['name']:<28}{asset['download_count']:>6}")
        if asset["name"].endswith(".dmg"):
            total += asset["download_count"]
print(f"DMG downloads total: {total}")
