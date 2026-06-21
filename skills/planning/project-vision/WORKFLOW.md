# Project Vision Workflow

## Init

1. Read existing context before asking questions:
   - `README.md`
   - `AGENTS.md`
   - `ROADMAP.md`
   - `docs/README.md`
   - relevant `docs/context/**`
   - existing `VISION.md`, if present
2. Ask only unresolved grill questions from [REFERENCE.md](REFERENCE.md).
3. Ask one question at a time and provide a recommended answer.
4. Stop once the answers close off obvious unintended branches; do not collapse to PRD/spec depth.
5. Create root `VISION.md` from the collapsed answers.
6. Wire `AGENTS.md` and the docs index so agents read `VISION.md` before substantial work.

## Apply

1. Read `VISION.md` before substantial planning, architecture, product, UX, or agent workflow work.
2. If requested work conflicts with `VISION.md`, raise the contradiction.
3. Do not edit `VISION.md` unless the user explicitly requests a vision update.

## Check

Judge one concrete piece of proposed work (a plan, PRD, spec, roadmap item, or diff/PR summary) against `VISION.md`.

1. Read `VISION.md`, paying closest attention to the `Will Not Do` clauses and the durable advantage.
2. **Argue the contradiction first.** Before forming a verdict, build the strongest case that the work *contradicts* the vision. Do not start from "this is probably fine" — a check that grades work in the same breath that proposed it will rubber-stamp it. The prosecution case comes before the verdict.
3. Issue one verdict, quoting the specific clause it turns on:
   - `ALIGNED` — serves the vision; no clause is strained.
   - `TENSION` — not a clean contradiction, but it strains a clause or the durable advantage.
   - `CONTRADICTS` — trips a `Will Not Do` clause or works against the stated direction.
4. Recommend an action: `proceed` (ALIGNED), `reshape` (TENSION — say concretely how), or `escalate` (CONTRADICTS — surface the vision-vs-work decision to the user; never silently proceed and never edit `VISION.md`).
5. Append one line to the repo's vision-check log (local-profile path; default `docs/vision/checks.jsonl`): `{ "date", "work", "verdict", "clause" }`.
6. If the repo has not been calibrated (see Calibrate), label the verdict **uncalibrated**.

## Calibrate (optional, per repo)

Calibration validates that *this* repo's `check` actually rejects the work this repo would reject. It is never required for `check` to run.

1. Mine the repo's own decision history for real past decisions: `git log`, reverted commits, `ROADMAP.md` rejected items, and `docs/adr/**` "we decided not to" calls.
2. Label each decision and store it as the repo's vision corpus (local-profile path; default `docs/vision/corpus.jsonl`): work that **shipped and was kept** → expected `ALIGNED`; work **reverted, rejected, or refused** → expected `CONTRADICTS` (or `TENSION`).
3. **Sufficiency gate:** if fewer than **8** labelled decisions exist (e.g. a brand-new project), skip calibration. `check` runs uncalibrated against `VISION.md` — this is expected and fine for young repos.
4. With ≥8, run `check` across the corpus and compare each verdict to its expected label → a confusion matrix. If `check` passes work you killed or rejects work you shipped, fix the `VISION.md` clauses (or the check procedure) before relying on it or wiring it into a gate.
5. The corpus and the check log are per-repo, committed artifacts. They are **not** part of the portable skill and never travel between clones.

## Review

Check whether `VISION.md` is crisp, stable, and in the right layer. Move implementation detail to specs, ADRs, package docs, app docs, workflow docs, or roadmap items.

## Update

Only update `VISION.md` when the user explicitly requests a vision update. Preserve strong current principles, remove stale claims, and keep changes limited to long-lived direction.
