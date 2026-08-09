# joint-design-review — improvement backlog

Updates the skill needs, found by running it. Each entry records what went wrong, so a
future edit fixes the cause and not the symptom. Clear an entry by editing `SKILL.md`
(or the referenced file) and deleting the row.

Status: `open` — not yet applied. `applied` rows are deleted, not archived.

---

## 1. Class A needs an over-explanation row

**Found:** Kingfield Quality review, 2026-08-09.

Class A #12 covers *jargon* in user copy — internal vocabulary swapped for a plain
instruction. It does not catch copy that is plain, accurate, and still says far too
much. The Quality intake form's customer-approval panel carried a heading, two
explanatory sentences, and a separate name + email + button sub-form beside the control
those sentences described. Every sentence passed the jargon test. The panel was still
condescending, and the reviewing agent did not flag it — the user did.

**Add as Class A #14 — over-explanation:** prose that restates what the control already
shows, or explains a consequence the reader already understands. Cut it. Trust the user.

**Boundary that keeps it Class A:** cutting explanation is Class A. Cutting a warning
about an irreversible, governed, or money-moving consequence is Class B — that warning
may exist because someone was harmed by its absence.

**Do not merge with #12.** Unclear copy and over-abundant copy are different failures
and need different prompts to be seen.

**Extend it to labels, not only prose.** Same review, same user, second instance: four
filters each carried a field label — Status, State, Type, Sort — above a control whose
own value already said the same thing. The reviewing agent measured the vertical cost
and still did not name the labels as the cause. A label that repeats the control's value
is over-explanation in one word instead of one sentence. The rule must cover field
labels, section headings, and helper text, or it will keep catching only paragraphs.

---

## 1b. The audit must ask what is deliberate before calling it broken

**Found:** Kingfield Quality review, 2026-08-09.

The mobile worklist showed one column, and the review filed it as responsive breakage.
It was a deliberate design decision. The user accepted the underlying point and rejected
the framing, and the finding had to be reclassified after the fact.

Two lessons, and the second is the useful one:

- A surface that looks under-built may be a decision the reviewer cannot see from the
  code. Prior design specs and screenshot sets in the repo are the place that decision
  is recorded, and preflight gate 3 already requires reading them. Gate 3 was run; it
  did not surface this. So gate 3 needs to ask specifically: **which of this area's
  current behaviours are deliberate?**
- Separate the artifact from the intent. Here the intent (show only the title on a
  phone) was sound, while the artifact (a 1056px table still scrolling sideways behind
  it) was not. Filing them as one finding made the whole thing rejectable. Findings
  should split along that line so the defect survives when the design choice is upheld.

Add to step 4: when a finding contradicts an apparently deliberate choice, state the
choice, say why it still costs the user, and offer the reference or evidence that a
better option exists — rather than asserting breakage.

---

## 1c. Accept and cite quality references

**Found:** Kingfield Quality review, 2026-08-09.

The user answered two findings with a screenshot of another product and made the work
conditional on reaching that bar: address it only if we hit this quality, otherwise
leave it alone. The skill has no place to put that, so it was invented on the spot
(`docs/design/references/` with a README that decomposes the reference into named
techniques).

**Add to the skill:** a references convention. A reference is stored in the repo, not
linked to a chat upload; it is decomposed into the specific techniques it demonstrates,
because "make it like Linear" is not actionable; it records who accepted it and against
which findings; and it can carry a **conditional bar** — the work is authorised only if
it reaches the reference, and a half-measure is explicitly worse than no change.

---

## 2. Audits need isolated tracking before they become tracker issues

**Found:** Kingfield Quality review, 2026-08-09.

Step 7 says "bead everything, before any implementation". In a repo running an agent
swarm this is unsafe: the moment findings become ready issues in the shared tracker, the
swarm claims and implements them — before the user has ruled on the Class B decisions,
and before they have agreed the Class A list is right. Writing to the shared tracker
also races the swarm's own writes to the same file.

`br` resists a second workspace in one repo by design: `br init --db <path>` inside a
repo that already has `.beads/` fails with "Already initialized", and the only override
is `--force`, which can target the discovered database. Do not reach for a second
tracker.

**The fix:** make `findings.jsonl` the audit's own tracker for the whole review, and
add an explicit **materialise** step that creates real tracker issues only on the user's
word.

- Give `findings.jsonl` rows the tracker's own field vocabulary — `title`,
  `description`, `type`, `priority`, `labels`, `dependsOn`, `status`, `acceptance` —
  so materialising is mechanical rather than a rewrite.
- Keep the file in the audit's own directory. It is invisible to `br` and `bv`, so no
  swarm can claim it.
- Materialise as one epic plus one child per row, writing the returned id back into
  each row's `bead` field. The review is complete when no row has a null `bead`.
- Never materialise before the Class B rulings land.

Rework step 7 around this, and state the swarm hazard as the reason so a future reader
does not "simplify" it back.

---

## 3. `static-scan.mjs` crashes on a file-path argument

**Found:** Kingfield Quality review, 2026-08-09.

`walk()` calls `readdirSync` on every argument, so passing a file rather than a
directory throws `ENOTDIR` and takes the whole scan down. Route files that sit beside a
directory (`quality.tsx` next to `quality/`) are a normal part of an area, so this is
hit on ordinary use.

**Fix:** `statSync` each root; walk directories, scan files directly, and report an
unreadable path as a skipped-root warning rather than a crash.

---

## 4. The screenshot harness needs a documented session warm-up

**Found:** Kingfield Quality review, 2026-08-09.

Captures of an authenticated app can silently produce sign-in pages. A stored browser
session whose short-lived token has expired sends the first navigation of each fresh
context to the login screen; later navigations succeed once the client refreshes. Three
of the first ten captures were of the login page, and the resulting screenshots looked
plausible enough to reason about.

**Fix:** the screenshot policy should require a warm-up navigation to a known
authenticated route, plus an assertion that the final URL is the requested one, before
any capture is kept. Add "the capture is of the page you asked for" to the evidence bar
in step 4.

---

## 5. Contention must be checked on the data path, not only the route files

**Found:** Kingfield Quality review, 2026-08-09.

Preflight gate 2 checks whether the area's files are contended. The Quality route files
were clean, so the area passed the gate — and the detail surface was nonetheless dead,
broken by an in-flight change to the backend service behind it. The audit spent real
effort diagnosing another agent's open work.

**Fix:** gate 2 should check the surfaces' data path too — the queries, services, and
validators the area reads — not just its component files. Name it explicitly: an area is
uncontended when neither its components nor the code it renders from is being edited.
