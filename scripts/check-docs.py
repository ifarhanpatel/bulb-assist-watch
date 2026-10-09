#!/usr/bin/env python3
"""Check local Markdown link targets without making network requests."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

root = Path(__file__).resolve().parents[1]
names = (root / "scripts/public-files.txt").read_text().splitlines()
errors = []
for name in names:
    if not name.endswith(".md"):
        continue
    path = root / name
    text = re.sub(r"```.*?```", "", path.read_text(), flags=re.S)
    for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", text):
        target = target.strip().strip("<>")
        parsed = urlsplit(target)
        if parsed.scheme or not parsed.path:
            continue
        destination = (path.parent / unquote(parsed.path)).resolve()
        if not destination.is_relative_to(root) or not destination.exists():
            errors.append(f"{name}: missing or external local target {target}")
        elif destination.is_file() and destination.relative_to(root).as_posix() not in names:
            errors.append(f"{name}: target excluded from public manifest: {target}")
for error in errors:
    print(error, file=sys.stderr)
print(f"Checked local link targets in {sum(n.endswith('.md') for n in names)} Markdown files")
sys.exit(bool(errors))
