#!/usr/bin/env node
/**
 * joint-design-review findings tracker.
 *
 * `findings.jsonl` IS the audit's tracker for the whole review. It stays a plain
 * file in the audit directory so no agent swarm can discover and claim the work
 * before the user has ruled on it. Only `materialise` turns rows into real
 * tracker issues, and only on the user's word.
 *
 *   node findings.mjs validate   <file>
 *   node findings.mjs summary    <file>
 *   node findings.mjs materialise <file> --epic "<title>" [--prefix-label design-review] [--apply]
 *
 * Without --apply, materialise prints the exact `br` commands and changes nothing.
 * With --apply it runs them and writes each returned id back into the row's `bead`.
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { note, out } from "./io.mjs";

const REQUIRED = ["id", "class", "dimension", "file", "summary"];
const CLASSES = new Set(["A", "B"]);

const [cmd, file, ...rest] = process.argv.slice(2);
if (!cmd || !file) {
  note(
    "usage: findings.mjs <validate|summary|materialise> <findings.jsonl> [options]",
  );
  process.exit(2);
}

const read = () =>
  readFileSync(file, "utf8")
    .split("\n")
    .filter((l) => l.trim())
    .map((l, i) => {
      try {
        return JSON.parse(l);
      } catch (e) {
        note(`line ${i + 1}: invalid JSON — ${e.message}`);
        process.exit(1);
      }
    });

const write = (rows) =>
  writeFileSync(file, `${rows.map((r) => JSON.stringify(r)).join("\n")}\n`);

const flag = (name, dflt = null) => {
  const i = rest.indexOf(`--${name}`);
  return i === -1 ? dflt : rest[i + 1];
};
const has = (name) => rest.includes(`--${name}`);

function validate(rows) {
  const problems = [];
  const seen = new Set();
  for (const r of rows) {
    const at = r.id ?? "(no id)";
    for (const k of REQUIRED) if (!r[k]) problems.push(`${at}: missing "${k}"`);
    if (r.class && !CLASSES.has(r.class)) problems.push(`${at}: class must be A or B`);
    if (seen.has(r.id)) problems.push(`${at}: duplicate id`);
    seen.add(r.id);
    if (r.class === "A" && (r.rank === null || r.rank === undefined))
      problems.push(`${at}: Class A carries no rank`);
  }
  // An unresolved dependsOn is a warning, not an error: reviews legitimately
  // depend on a decision in a sibling review ("other-review#B2") or on an issue
  // in the project tracker. Only a bare same-file-looking id that matches
  // nothing is worth flagging, and even then it may just be written next.
  for (const r of rows) {
    const dep = r.dependsOn;
    if (!dep) continue;
    const external = dep.includes("#") || dep.includes("-");
    if (!seen.has(dep) && !external)
      warnings.push(
        `${r.id}: dependsOn "${dep}" matches no row here. Use "<review>#${dep}" for a sibling review, or a tracker id.`,
      );
  }
  return problems;
}

// Unruled Class B is the NORMAL state of a freshly written report — the whole
// point is to put those decisions to the user. It blocks `materialise`, which
// checks it separately, and must not block `validate`.
const warnings = [];

const rows = read();

if (cmd === "validate") {
  const problems = validate(rows);
  if (problems.length) {
    note(`${problems.length} problem(s):`);
    for (const p of problems) note(`  - ${p}`);
    process.exit(1);
  }
  for (const w of warnings) note(`  warn: ${w}`);
  const openB = rows.filter((r) => r.class === "B" && r.status !== "ruled" && !r.ruling);
  out(
    `ok — ${rows.length} rows${openB.length ? `; ${openB.length} Class B awaiting a ruling (${openB.map((r) => r.id).join(", ")})` : ""}`,
  );
} else if (cmd === "summary") {
  const a = rows.filter((r) => r.class === "A");
  const b = rows.filter((r) => r.class === "B");
  const unruled = b.filter((r) => r.status !== "ruled" && !r.ruling);
  const unbeaded = rows.filter((r) => !r.bead);
  out(`rows        ${rows.length}`);
  out(`Class A     ${a.length}   (standing approval — fix without asking)`);
  out(`Class B     ${b.length}   (${unruled.length} awaiting a ruling)`);
  out(`unbeaded    ${unbeaded.length}`);
  out("");
  for (const r of [...a].sort((x, y) => (x.rank ?? 99) - (y.rank ?? 99)))
    out(
      `  ${String(r.rank ?? "-").padStart(2)}  ${r.id.padEnd(4)} ${(r.bead ? "[beaded] " : "").padEnd(9)}${r.classLabel ?? ""}`,
    );
  for (const r of b)
    out(`   B  ${r.id.padEnd(4)} ${r.status === "ruled" || r.ruling ? "[ruled]  " : "[OPEN]   "}${r.classLabel ?? ""}`);
  if (unbeaded.length === 0) out("\nComplete: every row carries a bead id.");
} else if (cmd === "materialise") {
  const problems = validate(rows);
  if (problems.length) {
    note("refusing to materialise — validate first:");
    for (const p of problems) note(`  - ${p}`);
    process.exit(1);
  }
  const openB = rows.filter((r) => r.class === "B" && r.status !== "ruled" && !r.ruling);
  if (openB.length) {
    note(
      `refusing to materialise — ${openB.length} Class B decision(s) still unruled: ${openB.map((r) => r.id).join(", ")}`,
    );
    process.exit(1);
  }
  const epicTitle = flag("epic");
  if (!epicTitle) {
    note("--epic \"<title>\" is required");
    process.exit(1);
  }
  const label = flag("prefix-label", "design-review");
  const apply = has("apply");

  const run = (args) => {
    if (!apply) {
      out(`br ${args.map((a) => (/\s/.test(a) ? JSON.stringify(a) : a)).join(" ")}`);
      return null;
    }
    const stdout = execFileSync("br", [...args, "--json"], { encoding: "utf8" });
    // A tracker that answers with something other than JSON (an upgrade notice,
    // a plain-text error) must not read as "no id returned" — that would leave
    // the row unbeaded and silently drop it from the epic.
    let parsed;
    try {
      parsed = JSON.parse(stdout);
    } catch (e) {
      note(`br ${args[0]} returned unparseable output — ${e.message}`);
      note(stdout.slice(0, 400));
      process.exit(1);
    }
    return parsed.id ?? parsed.issue?.id ?? parsed.issues?.[0]?.id ?? null;
  };

  const epicId = run(["create", epicTitle, "-t", "epic", "-p", "1", "-l", label]);
  const todo = rows.filter((r) => !r.bead && r.class === "A");
  for (const r of todo) {
    const labels = [label, r.classLabel ?? "finding", "standing-approval"].join(",");
    const body = [
      r.summary,
      "",
      `Location: ${r.file}${r.line ? `:${r.line}` : ""}`,
      r.reference ? `Reference: ${r.reference}` : null,
      r.ruling ? `Ruling: ${r.ruling}` : null,
      r.correction ? `Correction: ${r.correction}` : null,
      "",
      "Falsifying acceptance: a behavioural assertion that fails before the fix,",
      "plus a re-screenshot of the surface. \"It compiles\" is not acceptance.",
    ]
      .filter(Boolean)
      .join("\n");
    const id = run([
      "create",
      `[${r.id}] ${r.summary.slice(0, 70)}`,
      "-t", r.classLabel === "accessibility-defect" ? "bug" : "task",
      "-p", String(Math.min(3, Math.max(0, Math.ceil((r.rank ?? 5) / 3)))),
      "-l", labels,
      "-d", body,
    ]);
    if (apply && id) {
      r.bead = id;
      if (epicId) run(["dep", "add", id, epicId]);
    }
  }
  if (apply) {
    write(rows);
    out(`materialised ${todo.length} rows under ${epicId}`);
    out("remember: br sync --flush-only, then commit .beads/ with the report");
  } else {
    out(`\n(dry run — ${todo.length} rows. Re-run with --apply to execute.)`);
  }
} else {
  note(`unknown command: ${cmd}`);
  process.exit(2);
}
