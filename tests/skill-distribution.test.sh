#!/usr/bin/env bash
# Check a release export, or tracked checkout files plus explicit migration targets.
# Unrelated untracked skills from other sessions are excluded in a shared checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "${1:-$REPO_ROOT}" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse

root = pathlib.Path(sys.argv[1]).resolve()
errors = []

def check(condition, message):
    if not condition:
        errors.append(message)

def local_path(value):
    if not isinstance(value, str):
        raise ValueError("migration paths must be strings")
    path = pathlib.PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"migration path escapes repository: {value}")
    return root / path

try:
    manifest = json.loads((root / "migrations.json").read_text())
    if manifest.get("version") != 1 or not isinstance(manifest.get("prompts"), list):
        raise ValueError("migrations.json must declare version 1 and a prompts array")
    migrations = manifest["prompts"]
    if not migrations:
        raise ValueError("prompt migration list must not be empty")

    # An export has no Git metadata. In a checkout inspect published/staged files
    # and the named migration destinations, not other sessions' untracked work.
    probe = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    if probe.returncode == 0 and pathlib.Path(probe.stdout.strip()).resolve() == root:
        tracked = subprocess.check_output(
            ["git", "-C", str(root), "ls-files", "-z"], text=True,
        ).split("\0")
        files = {name for name in tracked if name and (root / name).is_file()}
    else:
        files = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()}

    names, sources, targets = set(), set(), set()
    for item in migrations:
        name, old, new = item["name"], item["from"], item["to"]
        old_path, new_path = local_path(old), local_path(new)
        check(name not in names, f"duplicate migration name: {name}")
        check(old not in sources, f"duplicate migration source: {old}")
        check(new not in targets, f"duplicate migration destination: {new}")
        names.add(name)
        sources.add(old)
        targets.add(new)
        check(old == f"prompts/{name}.md", f"unexpected legacy prompt path: {old}")
        check(not old_path.exists(), f"legacy prompt still present: {old}")
        check(new_path.is_file(), f"migrated skill missing: {new}")
        check(
            re.fullmatch(r"skills/[^/]+/" + re.escape(name) + r"/SKILL\.md", new) is not None,
            f"migration destination does not match skill name: {new}",
        )
        if new_path.is_file():
            files.add(new)

    check(not any(p.startswith("prompts/") for p in files), "legacy prompts directory is still published")
    check(
        not any(p.startswith("deprecated/") and p.endswith("/SKILL.md") for p in files),
        "archive contains a discoverable SKILL.md entrypoint",
    )
    entries = sorted(p for p in files if p.startswith("skills/") and p.endswith("/SKILL.md"))
    check(bool(entries), "no active skill packages found")
    identities = {}
    for relative in entries:
        path = root / relative
        check(len(pathlib.PurePosixPath(relative).parts) == 4, f"unexpected package layout: {relative}")
        text = path.read_text()
        frontmatter = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.S)
        if not frontmatter:
            errors.append(f"missing frontmatter: {relative}")
            continue
        # The existing lint-skills check parses YAML. This check enforces the
        # portable identity contract across the entire published collection.
        name_fields = re.findall(r"^name:\s*(.*?)\s*$", frontmatter.group(1), re.M)
        if len(name_fields) != 1:
            errors.append(f"expected exactly one name field: {relative}")
            continue
        name = name_fields[0].strip("\"'")
        check(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) is not None, f"invalid skill name: {relative}")
        check(len(name) <= 64, f"skill name exceeds 64 characters: {relative}")
        check(name == path.parent.name, f"name does not match directory: {relative}")
        check(name not in identities, f"duplicate skill identity {name}: {relative} and {identities.get(name)}")
        identities[name] = relative
        check(
            re.search(r"/(?:Users|home)/[^\s`<>)]*(?:SKILL\.md|prompts/[^\s`<>)]*\.md)", text) is None,
            f"entrypoint depends on an author-machine prompt/skill path: {relative}",
        )

        # Validate concrete Markdown links in the entrypoint, excluding example
        # code blocks and external URLs. Bundled references must stay in-package.
        prose = re.sub(r"(?ms)^```[^\n]*\n.*?^```[^\n]*$", "", text)
        for target in re.findall(r"\]\(([^\s)]+)\)", prose):
            target = urllib.parse.unquote(target.strip("<>"))
            if urllib.parse.urlsplit(target).scheme or target.startswith("#"):
                continue
            target = target.split("#", 1)[0]
            if not target:
                continue
            resolved = (path.parent / target).resolve()
            check(resolved.is_relative_to(path.parent.resolve()), f"reference escapes package: {relative} -> {target}")
            check(resolved.exists(), f"missing bundled reference: {relative} -> {target}")

    for item in migrations:
        check(identities.get(item["name"]) == item["to"], f"migrated identity is not discoverable: {item['name']}")
except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
    errors.append(str(exc))

if errors:
    for error in errors:
        print(f"not ok - {error}", file=sys.stderr)
    sys.exit(1)
print(f"ok - {len(migrations)} prompt migrations resolve to unique native skills")
print(f"ok - {len(entries)} published packages have portable names and bundled references")
print("ok - legacy prompts and archived SKILL.md files are excluded from publication")
PY
