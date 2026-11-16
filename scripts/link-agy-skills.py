#!/usr/bin/env python3
"""Expose this collection's universal installs to Antigravity CLI.

skills@1.7.1 classifies agy as universal and skips its global discovery folder.
This helper only creates missing links. It never removes or replaces a path.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys

SOURCE = "ryangriffinau/skills"
SAFE_NAME = re.compile(r"[a-z0-9][a-z0-9-]{0,63}\Z")


def plan(user_dir):
    lock = user_dir / ".agents/.skill-lock.json"
    try:
        data = json.loads(lock.read_text())
    except json.JSONDecodeError as error:
        raise ValueError(f"Invalid JSON in skills lock: {lock}") from error
    if not isinstance(data, dict) or not isinstance(data.get("skills"), dict):
        raise ValueError(f"Invalid skills lock: {lock}")
    source_root = user_dir / ".agents/skills"
    target_root = user_dir / ".gemini/antigravity-cli/skills"
    for directory in [user_dir / ".gemini", target_root.parent, target_root]:
        if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
            raise ValueError(f"Unexpected discovery directory: {directory}")
    missing = []
    present = 0
    for name, entry in sorted(data["skills"].items()):
        if not isinstance(entry, dict):
            raise ValueError(f"Invalid lock entry: {name}")
        if entry.get("source") != SOURCE:
            continue
        if not SAFE_NAME.fullmatch(name):
            raise ValueError(f"Unsafe skill name: {name!r}")
        source = source_root / name
        target = target_root / name
        if not (source / "SKILL.md").is_file():
            raise ValueError(f"Missing installed entrypoint: {source / 'SKILL.md'}")
        if target.is_symlink():
            if target.resolve() != source.resolve():
                raise ValueError(f"Conflicting link: {target}")
            present += 1
        elif target.exists():
            raise ValueError(f"Existing path is not a managed link: {target}")
        else:
            missing.append((source, target))
    return present, missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Report missing links without writing (default)")
    mode.add_argument("--apply", action="store_true", help="Create missing links after checking every target")
    parser.add_argument("--user-dir", type=Path, default=Path.home(), help="User directory; useful for isolated checks")
    args = parser.parse_args()
    try:
        present, missing = plan(args.user_dir.expanduser().absolute())
        if args.apply:
            # All names, sources, and destinations have passed preflight.
            for source, target in missing:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(os.path.relpath(source, target.parent), target_is_directory=True)
            print(f"agy skills: {present} already linked, {len(missing)} linked")
            return 0
        print(f"agy skills: {present} linked, {len(missing)} missing")
        return 1 if missing else 0
    except (OSError, ValueError, RuntimeError) as error:
        print(f"agy skills: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
