#!/usr/bin/env bash
# Per-case acceptance oracle for the portable DCG packs.
#
# Each command is passed to `dcg explain` as one inert argument. Commands are
# never eval'd or executed. `dcg simulate` is intentionally not the oracle: its
# output is aggregate-only and cannot associate a decision with an input row.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCG_DIR="$(cd "$TEST_DIR/.." && pwd)"
CASES_FILE="${DCG_CASES_FILE:-$TEST_DIR/fixtures/cases.jsonl}"
KNOWN_GAPS_FILE="${DCG_KNOWN_GAPS_FILE:-$TEST_DIR/fixtures/known-gaps.jsonl}"

die() {
  printf 'verify.sh: error: %s\n' "$*" >&2
  exit 1
}

command -v dcg >/dev/null 2>&1 || die "dcg is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ -f "$CASES_FILE" ]] || die "cases fixture not found: $CASES_FILE"
[[ -f "$KNOWN_GAPS_FILE" ]] || die "known-gaps fixture not found: $KNOWN_GAPS_FILE"

# Standalone runs exercise the packs from this checkout, independent of the
# operator's live DCG config. Callers testing a candidate config can provide
# DCG_CONFIG explicitly; that value is preserved.
TMP_DIR=""
if [[ -z "${DCG_CONFIG:-}" ]]; then
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dcg-verify.XXXXXX")"
  trap 'rm -rf "$TMP_DIR"' EXIT INT TERM HUP
  {
    printf '[packs]\n'
    printf 'custom_paths = ["%s/packs/*.yaml"]\n' "$DCG_DIR"
    printf 'enabled = [\n'
    for pack in "$DCG_DIR"/packs/*.yaml; do
      printf '  "%s",\n' "$(basename "$pack" .yaml)"
    done
    printf ']\n'
  } >"$TMP_DIR/config.toml"
  export DCG_CONFIG="$TMP_DIR/config.toml"
fi

total=0
passed=0
failed=0
line_number=0

while IFS= read -r record || [[ -n "$record" ]]; do
  line_number=$((line_number + 1))
  [[ -n "$record" ]] || continue

  if ! jq -e '
    type == "object" and
    (.command | type == "string" and length > 0) and
    (.expect == "allow" or .expect == "deny") and
    (if .expect == "deny"
     then (.rule | type == "string" and length > 0)
     else (has("rule") | not)
     end)
  ' >/dev/null 2>&1 <<<"$record"; then
    printf 'not ok %d - malformed fixture row at %s:%d\n' \
      "$((total + 1))" "$CASES_FILE" "$line_number" >&2
    failed=$((failed + 1))
    total=$((total + 1))
    continue
  fi

  command_text="$(jq -r '.command' <<<"$record")"
  expected="$(jq -r '.expect' <<<"$record")"
  expected_rule="$(jq -r '.rule // empty' <<<"$record")"
  total=$((total + 1))

  if ! output="$(dcg explain --format json "$command_text" 2>&1)"; then
    printf 'not ok %d - dcg explain failed for fixture line %d: %s\n%s\n' \
      "$total" "$line_number" "$command_text" "$output" >&2
    failed=$((failed + 1))
    continue
  fi

  if ! jq -e . >/dev/null 2>&1 <<<"$output"; then
    printf 'not ok %d - dcg explain returned non-JSON for fixture line %d: %s\n%s\n' \
      "$total" "$line_number" "$command_text" "$output" >&2
    failed=$((failed + 1))
    continue
  fi

  if [[ "$expected" == "deny" ]]; then
    if jq -e --arg rule "$expected_rule" \
      '(.schema_version == 2 or .schema_version == 3) and .decision == "deny" and .match.rule_id == $rule' \
      >/dev/null <<<"$output"; then
      printf 'ok %d - deny: %s\n' "$total" "$command_text"
      passed=$((passed + 1))
    else
      actual="$(jq -r '"schema=" + (.schema_version | tostring) + " decision=" + (.decision // "missing") + " rule=" + (.match.rule_id // "missing")' <<<"$output")"
      printf 'not ok %d - expected deny by %s for: %s (%s)\n' \
        "$total" "$expected_rule" "$command_text" "$actual" >&2
      failed=$((failed + 1))
    fi
  else
    if jq -e \
      '(.schema_version == 2 or .schema_version == 3) and .decision == "allow" and ((has("match") | not) or .match == null)' \
      >/dev/null <<<"$output"; then
      printf 'ok %d - allow: %s\n' "$total" "$command_text"
      passed=$((passed + 1))
    else
      actual="$(jq -r '"schema=" + (.schema_version | tostring) + " decision=" + (.decision // "missing") + " rule=" + (.match.rule_id // "missing")' <<<"$output")"
      printf 'not ok %d - expected allow for: %s (%s)\n' \
        "$total" "$command_text" "$actual" >&2
      failed=$((failed + 1))
    fi
  fi
done <"$CASES_FILE"

# Known gaps document stateless-analysis limits. Validate their documentation
# schema, but deliberately do not run or assert their observed decision.
known_gaps="$(jq -s -e '
  if all(.[];
    type == "object" and
    .observed == "allow" and
    (.command | type == "string" and length > 0) and
    ((.reason // .precondition) | type == "string" and length > 0) and
    (has("expect") | not)
  ) then length else error("invalid known-gap row") end
' "$KNOWN_GAPS_FILE")" || die "malformed known-gaps fixture: $KNOWN_GAPS_FILE"

printf '\nverify.sh: %d/%d cases passed; %d known gaps documented\n' \
  "$passed" "$total" "$known_gaps"

[[ "$failed" -eq 0 ]] || exit 1
