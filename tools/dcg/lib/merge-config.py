#!/usr/bin/env python3
"""Source-preserving merge for the two [packs] arrays owned by install.sh."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path


def toml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def render_array(values: list[str]) -> str:
    body = "".join(f"  {toml_string(value)},\n" for value in values)
    return f"[\n{body}]"


def array_end(text: str, start: int) -> int:
    """Return the offset after a TOML array, ignoring brackets in strings/comments."""
    depth = 0
    index = start
    mode = "normal"

    while index < len(text):
        chunk = text[index : index + 3]
        char = text[index]

        if mode == "comment":
            if char == "\n":
                mode = "normal"
        elif mode == "basic":
            if char == "\\":
                index += 1
            elif char == '"':
                mode = "normal"
        elif mode == "literal":
            if char == "'":
                mode = "normal"
        elif mode == "multiline_basic":
            if chunk == '"""':
                mode = "normal"
                index += 2
            elif char == "\\":
                index += 1
        elif mode == "multiline_literal":
            if chunk == "'''":
                mode = "normal"
                index += 2
        elif chunk == '"""':
            mode = "multiline_basic"
            index += 2
        elif chunk == "'''":
            mode = "multiline_literal"
            index += 2
        elif char == '"':
            mode = "basic"
        elif char == "'":
            mode = "literal"
        elif char == "#":
            mode = "comment"
        elif char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                return index + 1

        index += 1

    raise ValueError("unterminated TOML array")


def section_bounds(text: str) -> tuple[int, int] | None:
    headers = list(re.finditer(r"(?m)^[ \t]*\[packs\][ \t]*(?:#.*)?$", text))
    if len(headers) > 1:
        raise ValueError("multiple literal [packs] sections")
    if not headers:
        return None

    start = headers[0].end()
    following = re.search(r"(?m)^[ \t]*\[{1,2}[^\n]+\]{1,2}[ \t]*(?:#.*)?$", text[start:])
    end = start + following.start() if following else len(text)
    return start, end


def replace_array(text: str, section: tuple[int, int], key: str, values: list[str]) -> str:
    section_start, section_end = section
    body = text[section_start:section_end]
    assignment = re.search(rf"(?m)^[ \t]*{re.escape(key)}[ \t]*=", body)
    if assignment is None:
        insertion = section_start
        line = f"\n{key} = {render_array(values)}\n"
        return text[:insertion] + line + text[insertion:]

    value_start = section_start + assignment.end()
    open_bracket = text.find("[", value_start, section_end)
    if open_bracket < 0:
        raise ValueError(f"[packs].{key} is not written as an array")
    close_bracket = array_end(text, open_bracket)
    return text[:open_bracket] + render_array(values) + text[close_bracket:]


def merge(source: str, enabled: list[str], custom_path: str) -> str:
    try:
        document = tomllib.loads(source) if source.strip() else {}
    except tomllib.TOMLDecodeError as exc:
        raise ValueError(f"existing config is invalid TOML: {exc}") from exc

    packs = document.get("packs", {})
    if not isinstance(packs, dict):
        raise ValueError("[packs] must be a TOML table")

    current_enabled = packs.get("enabled", [])
    current_paths = packs.get("custom_paths", [])
    if not isinstance(current_enabled, list) or not all(isinstance(item, str) for item in current_enabled):
        raise ValueError("[packs].enabled must be an array of strings")
    if not isinstance(current_paths, list) or not all(isinstance(item, str) for item in current_paths):
        raise ValueError("[packs].custom_paths must be an array of strings")

    merged_enabled = list(dict.fromkeys([*current_enabled, *enabled]))
    merged_paths = list(dict.fromkeys([*current_paths, custom_path]))
    if merged_enabled == current_enabled and merged_paths == current_paths:
        return source

    bounds = section_bounds(source)
    if bounds is None:
        if packs:
            raise ValueError("existing packs configuration is not represented by a literal [packs] table")
        separator = "" if not source or source.endswith("\n\n") else ("\n" if source.endswith("\n") else "\n\n")
        candidate = (
            source
            + separator
            + "[packs]\n"
            + f"custom_paths = {render_array(merged_paths)}\n"
            + f"enabled = {render_array(merged_enabled)}\n"
        )
    else:
        candidate = source
        # Recompute section offsets after each source edit.
        candidate = replace_array(candidate, section_bounds(candidate), "custom_paths", merged_paths)  # type: ignore[arg-type]
        candidate = replace_array(candidate, section_bounds(candidate), "enabled", merged_enabled)  # type: ignore[arg-type]

    try:
        reparsed = tomllib.loads(candidate)
    except tomllib.TOMLDecodeError as exc:
        raise ValueError(f"merged config is invalid TOML: {exc}") from exc
    if reparsed.get("packs", {}).get("enabled") != merged_enabled:
        raise ValueError("merged enabled list failed structural verification")
    if reparsed.get("packs", {}).get("custom_paths") != merged_paths:
        raise ValueError("merged custom_paths list failed structural verification")
    return candidate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--enabled", action="append", default=[])
    parser.add_argument("--custom-path", required=True)
    args = parser.parse_args()

    source = args.input.read_text(encoding="utf-8") if args.input.exists() else ""
    try:
        candidate = merge(source, args.enabled, args.custom_path)
    except ValueError as exc:
        print(f"merge-config.py: error: {exc}", file=sys.stderr)
        return 1
    args.output.write_text(candidate, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
