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

const REQUIRED = ["id", "class", "dimension", "file", "summary"];
const CLASSES = new Set(["A", "B"]);

const [cmd, file, ...rest] = process.argv.slice(2);
if (!cmd || !file) {
  console.error(
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
        console.error(`line ${i + 1}: invalid JSON — ${e.message}`);
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
    if (r.class === "B" && r.status !== "ruled" && !r.ruling)
      problems.push(`${at}: Class B carries no ruling — it must be put to the user`);
    if (r.class === "A" && r.rank == null)
      problems.push(`${at}: Class A carries no rank`);
  }
  // every dependsOn must resolve to a known id or an external tracker id
  for (const r of rows) {
    const dep = r.dependsOn;
    if (dep && !seen.has(dep) && !/-/.test(dep))
      problems.push(`${r.id}: dependsOn "${dep}" matches no row and is not an external id`);
  }
  return problems;
}

const rows = read();

if (cmd === "validate") {
  const problems = validate(rows);
  if (problems.length) {
    console.error(`${problems.length} problem(s):`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  console.log(`ok — ${rows.length} rows`);
} else if (cmd === "summary") {
  const a = rows.filter((r) => r.class === "A");
  const b = rows.filter((r) => r.class === "B");
  const unruled = b.filter((r) => r.status !== "ruled" && !r.ruling);
  const unbeaded = rows.filter((r) => !r.bead);
  console.log(`rows        ${rows.length}`);
  console.log(`Class A     ${a.length}   (standing approval — fix without asking)`);
  console.log(`Class B     ${b.length}   (${unruled.length} awaiting a ruling)`);
  console.log(`unbeaded    ${unbeaded.length}`);
  console.log("");
  for (const r of [...a].sort((x, y) => (x.rank ?? 99) - (y.rank ?? 99)))
    console.log(
      `  ${String(r.rank ?? "-").padStart(2)}  ${r.id.padEnd(4)} ${(r.bead ? "[beaded] " : "").padEnd(9)}${r.classLabel ?? ""}`,
    );
  for (const r of b)
    console.log(`   B  ${r.id.padEnd(4)} ${r.status === "ruled" || r.ruling ? "[ruled]  " : "[OPEN]   "}${r.classLabel ?? ""}`);
  if (unbeaded.length === 0) console.log("\nComplete: every row carries a bead id.");
} else if (cmd === "materialise") {
  const problems = validate(rows);
  if (problems.length) {
    console.error("refusing to materialise — validate first:");
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  const openB = rows.filter((r) => r.class === "B" && r.status !== "ruled" && !r.ruling);
  if (openB.length) {
    console.error(
      `refusing to materialise — ${openB.length} Class B decision(s) still unruled: ${openB.map((r) => r.id).join(", ")}`,
    );
    process.exit(1);
  }
  const epicTitle = flag("epic");
  if (!epicTitle) {
    console.error("--epic \"<title>\" is required");
    process.exit(1);
  }
  const label = flag("prefix-label", "design-review");
  const apply = has("apply");

  const run = (args) => {
    if (!apply) {
      console.log(`br ${args.map((a) => (/\s/.test(a) ? JSON.stringify(a) : a)).join(" ")}`);
      return null;
    }
    const out = execFileSync("br", [...args, "--json"], { encoding: "utf8" });
    const parsed = JSON.parse(out);
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
    console.log(`materialised ${todo.length} rows under ${epicId}`);
    console.log("remember: br sync --flush-only, then commit .beads/ with the report");
  } else {
    console.log(`\n(dry run — ${todo.length} rows. Re-run with --apply to execute.)`);
  }
} else {
  console.error(`unknown command: ${cmd}`);
  process.exit(2);
}
