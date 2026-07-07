# Grading & Trends

## Grade scale

Each lens gets a letter grade with optional `+`/`-`. Anchor every grade to **evidence**, not vibe — a grade is a claim you can defend with the file:line findings in that lens's companion.

| Grade | Meaning |
|---|---|
| **A** | Meets the bar with margin; self-enforcing (the right thing is the default and CI/lint protects it). |
| **B** | Solid; known, bounded gaps with a clear path. |
| **C** | Functional but with a structural weakness that will bite as the team/scale grows. |
| **D** | Materially deficient; active risk. |
| **F** | Broken / exploitable / absent where it must exist. |

`+`/`-` are within-band nuance. Use the lens's own anchors in [lens-catalog.md](lens-catalog.md) to place the letter; use `±` for "top/bottom of the band."

**Grade against the repo's stated standard.** If `AGENTS.md` bans `any` and the repo carries hundreds, Type safety cannot be an A no matter how clean the rest is — the repo is failing a rule it set itself. Stated rules are the strongest anchors.

## Overall grade

The Overall is **not** a pure average. Derive it as the weighted central tendency, then apply two rules:

1. **Floors bind.** Any lens at **D/F**, or any unresolved **P0/launch-blocking** finding, caps the Overall regardless of how strong other lenses are. State the cap explicitly ("Overall held to B by the dependency-advisory backlog").
2. **Scope shifts are honest.** If a run *adds* a lens that surfaces a serious gap, the Overall can drop even when every pre-existing lens improved. Say so — "engineering improved; Overall dipped because the new tenancy lens found a P0." This is the example report's central move and it's a feature: the score reflects reality, not momentum.

Per-lens `weight` lives in the profile (default: equal). Security, tenancy, and testing typically carry higher weight for products handling customer data.

## Trend mechanic

Trends are computed, never recalled:

1. Read the prior run's grades from `scorecard.json`.
2. For each lens, compare this run's grade to the prior:
   - higher band or `+` step → **↑**
   - same → **→**
   - lower → **↓**
   - lens new this run → **(new)**
   - lens retired → drop the row, note it in SUMMARY.
3. Render the arrow in the scorecard's Direction column.

A grade can hold (`→`) while the *notes* change — that's expected and worth narrating (e.g. "held at B+: one gap closed, one opened"). Don't move a letter without a finding that justifies the move.

## Registry schema

The registry is the longitudinal source of truth. Two files, kept in sync:

- `scorecard.json` — machine-readable; the trend mechanic reads this.
- `REGISTRY.md` — human-readable table of every run (newest first).

`scorecard.json` shape:

```json
{
  "repo": "platform-monorepo",
  "lenses": ["security", "tenancy", "architecture", "type-safety", "testing",
             "performance", "observability", "sprawl", "dry-soc", "design-tokens",
             "accessibility", "dependencies", "ci-cd", "docs", "live-site"],
  "runs": [
    {
      "id": "2026-W12",                          // illustrative shape — not real data
      "date": "2026-03-19",
      "mode": "quick",
      "overall": "B-",
      "grades": {
        "security": "B-", "type-safety": "C+", "sprawl": "C+", "...": "..."
      },
      "metrics": {
        "files_over_cap": 80, "any_count": 100, "as_count": 150,
        "arbitrary_hex": 200, "audit_critical": 0, "audit_high": 0,
        "test_files": 240, "withindex": 250, "collect": 25
      },
      "p0_count": 0,
      "notes": "Baseline. Quick single-pass; not adversarially verified."
    }
  ]
}
```

(The block above is an illustrative shape — JSON does not allow `//` comments, so the real file omits them. The consuming repo's actual registry lives in its review home.) Each run appends one object to `runs`. Keep `lenses` stable so columns line up; when the set changes, update it and note the change in that run's SUMMARY. `metrics` carries the raw numbers so a future run can show "80 → 74" deltas, not just letter moves.

## Confidence & honesty

- A `quick`/`baseline` run is provisional — label grades as not adversarially verified. A `full` run's grades are verifier-backed.
- Never round a grade up to look like progress. If a number worsened, the arrow points down even if the narrative is otherwise positive.
- Distinguish *measured* findings (counts, file:line) from *judged* ones (architecture opinion). The scorecard's credibility is the measured spine.
