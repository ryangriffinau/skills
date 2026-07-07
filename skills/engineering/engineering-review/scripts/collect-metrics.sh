#!/usr/bin/env bash
# collect-metrics.sh — portable quantitative map for an engineering-review run.
# Emits JSON to stdout. Stack-agnostic; degrades gracefully when a tool is absent.
# Requires: ripgrep (rg). Optional: git, gh, pnpm.
#
# Usage:
#   scripts/collect-metrics.sh [REPO_ROOT] [SIZE_CAP]
#   REPO_ROOT defaults to the current directory; SIZE_CAP defaults to 500 (LOC).
#
# Tune the globs/patterns per stack in the profile if the defaults misfire.
set -uo pipefail

ROOT="${1:-.}"
CAP="${2:-500}"
cd "$ROOT" || { echo "{\"error\":\"cannot cd to $ROOT\"}"; exit 1; }

# Source globs: TS/TSX, excluding vendored/generated noise. Edit per stack.
SRC=(-g '*.ts' -g '*.tsx'
     -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/.next/**'
     -g '!**/build/**' -g '!**/_generated/**' -g '!**/*.gen.ts' -g '!**/sanity.types.ts')

# count PATTERN  -> total matching occurrences across source files (rg -o, one per line)
count() { rg -o "$1" "${SRC[@]}" . 2>/dev/null | wc -l | tr -d ' '; }
# files GLOB...   -> number of files matching
files() { rg --files "$@" . 2>/dev/null | wc -l | tr -d ' '; }

SRC_FILES=$(files "${SRC[@]}")
# Single robust pass: sum per-file line counts (ignore EVERY "total" line, so xargs
# batching into multiple wc invocations can't truncate the sum), and count over-cap files.
read -r OVER_CAP TOTAL_LOC < <(rg --files "${SRC[@]}" . 2>/dev/null | xargs wc -l 2>/dev/null \
  | awk -v c="$CAP" '$2!="total"{ if($1>c) n++; loc+=$1 } END{ print n+0, loc+0 }')

ANY=$(count ': any\b|as any\b|<any[>,]|\bany\[\]')
# Type-ASSERTION `as X` only. Exclude namespace imports / re-exports / import aliases
# (`import * as React`, `export * as x`, `{ Foo as Bar } from`) — those are not assertions
# and are not what the no-`as` rule bans. Line-based (a line rarely has two assertions).
AS_ASSERT=$(rg -N --no-heading '\bas [A-Z][A-Za-z0-9_]*' "${SRC[@]}" . 2>/dev/null \
  | rg -v '\bimport\b|\bexport\b|\bfrom\b' 2>/dev/null | wc -l | tr -d ' ')
TS_IGNORE=$(count '@ts-(ignore|nocheck|expect-error)')
LINT_DISABLE=$(count 'eslint-disable|biome-ignore')
# Non-null `!` assertion: identifier/closing-bracket + `!` + code punctuation. The trailing
# code-punct class ([.,;)\]]) keeps prose exclamations ("done!", "sign up!") out. Approximate.
NONNULL=$(count '[A-Za-z0-9_\])]!([.,;)\]])')
HEX=$(count '(text|bg|border|fill|stroke|from|to|via)-\[#')
HANDLE_BOTH=$(count 'instanceof Date \?')
TODO=$(count '\b(TODO|FIXME|HACK|XXX)\b')
CONSOLE=$(count 'console\.(log|error|warn|debug)')
# Empty catch — multiline so `catch (e) {\n}` is caught, not just single-line `catch {}`.
SWALLOW=$(rg -U -o 'catch\s*(\([^)]*\))?\s*\{\s*\}' "${SRC[@]}" . 2>/dev/null | wc -l | tr -d ' ')

TEST_FILES=$(files -g '*.test.ts' -g '*.test.tsx' -g '*.spec.ts' -g '*.spec.tsx' -g '!**/node_modules/**')

# Convex / data-access (no-op to 0 in non-Convex repos)
CONVEX_FNS=$(rg -o 'export const \w+ = (internal)?(query|mutation|action)' -g '*.ts' -g '!**/node_modules/**' . 2>/dev/null | wc -l | tr -d ' ')
WITHINDEX=$(rg -o '\.withIndex\(' -g '*.ts' -g '!**/node_modules/**' . 2>/dev/null | wc -l | tr -d ' ')
COLLECT=$(rg -o '\.collect\(\)' -g '*.ts' -g '!**/node_modules/**' . 2>/dev/null | wc -l | tr -d ' ')

# Dependency advisories (optional)
AUDIT_C=0; AUDIT_H=0; AUDIT_M=0; AUDIT_L=0
if command -v pnpm >/dev/null 2>&1; then
  AUDIT_JSON=$(pnpm audit --json 2>/dev/null)
  if [ -n "$AUDIT_JSON" ] && command -v jq >/dev/null 2>&1; then
    AUDIT_C=$(printf '%s' "$AUDIT_JSON" | jq -r '.metadata.vulnerabilities.critical // 0' 2>/dev/null | tail -1)
    AUDIT_H=$(printf '%s' "$AUDIT_JSON" | jq -r '.metadata.vulnerabilities.high // 0' 2>/dev/null | tail -1)
    AUDIT_M=$(printf '%s' "$AUDIT_JSON" | jq -r '.metadata.vulnerabilities.moderate // 0' 2>/dev/null | tail -1)
    AUDIT_L=$(printf '%s' "$AUDIT_JSON" | jq -r '.metadata.vulnerabilities.low // 0' 2>/dev/null | tail -1)
  fi
fi

# Git / PR signals (optional)
OPEN_PRS="null"
if command -v gh >/dev/null 2>&1; then
  OPEN_PRS=$(gh pr list --state open --json number --jq 'length' 2>/dev/null || echo null)
fi
CI_WORKFLOWS=$(ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | wc -l | tr -d ' ')

cat <<JSON
{
  "src_files": ${SRC_FILES:-0},
  "total_loc": ${TOTAL_LOC:-0},
  "size_cap": ${CAP},
  "files_over_cap": ${OVER_CAP:-0},
  "any_count": ${ANY:-0},
  "as_count": ${AS_ASSERT:-0},
  "ts_ignore": ${TS_IGNORE:-0},
  "lint_disable": ${LINT_DISABLE:-0},
  "non_null": ${NONNULL:-0},
  "arbitrary_hex": ${HEX:-0},
  "handle_both": ${HANDLE_BOTH:-0},
  "todo_fixme": ${TODO:-0},
  "console_calls": ${CONSOLE:-0},
  "empty_catch": ${SWALLOW:-0},
  "test_files": ${TEST_FILES:-0},
  "convex_fns": ${CONVEX_FNS:-0},
  "withindex": ${WITHINDEX:-0},
  "collect": ${COLLECT:-0},
  "audit_critical": ${AUDIT_C:-0},
  "audit_high": ${AUDIT_H:-0},
  "audit_moderate": ${AUDIT_M:-0},
  "audit_low": ${AUDIT_L:-0},
  "open_prs": ${OPEN_PRS},
  "ci_workflows": ${CI_WORKFLOWS:-0}
}
JSON
