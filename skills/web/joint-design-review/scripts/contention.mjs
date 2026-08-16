#!/usr/bin/env node
/**
 * joint-design-review contention check — preflight gate 2, mechanised.
 *
 *   node contention.mjs <area-path> [<area-path> ...] [--since <git-ref>]
 *
 * An area is uncontended when neither its own files NOR the code it renders
 * from is being edited. Checking only the component files is what let a review
 * pass the gate and then spend its effort diagnosing a dead surface that
 * another agent had broken in the backend service behind it.
 *
 * So this resolves the area's non-relative imports (its data path) back to real
 * files in the repo, then reports dirty state and recent commits across BOTH
 * sets. Exit 1 if anything in either set is dirty.
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { note, out } from "./io.mjs";

const args = process.argv.slice(2);
const sinceIdx = args.indexOf("--since");
const since = sinceIdx === -1 ? "HEAD~20" : args[sinceIdx + 1];
const roots = args.filter(
  (a, i) => !a.startsWith("--") && !(sinceIdx !== -1 && i === sinceIdx + 1),
);
if (!roots.length) {
  note("usage: contention.mjs <area-path> [...] [--since <ref>]");
  process.exit(2);
}

const git = (a) => execFileSync("git", a, { encoding: "utf8" }).trim();
const SRC = /\.(tsx|jsx|ts|js|vue|svelte|astro)$/;

function* walk(p) {
  let st;
  try {
    st = statSync(p);
  } catch {
    return;
  }
  if (st.isFile()) {
    if (SRC.test(p)) yield p;
    return;
  }
  for (const n of readdirSync(p)) {
    if (n === "node_modules" || n.startsWith(".")) continue;
    yield* walk(join(p, n));
  }
}

const areaFiles = [...new Set(roots.flatMap((r) => [...walk(r)]))];

// A root that matches nothing means a typo or the wrong cwd. Reporting
// "uncontended" off zero files is worse than failing: it passes the gate.
const empty = roots.filter((r) => [...walk(r)].length === 0);
if (empty.length) {
  note(`no source files under: ${empty.join(", ")}`);
  note("Check the path and the working directory. Refusing to report on nothing.");
  process.exit(2);
}

// --- resolve the data path: workspace-scoped imports the area reads from.
const specifiers = new Set();
for (const f of areaFiles) {
  const src = readFileSync(f, "utf8");
  for (const m of src.matchAll(/from\s+["']([^"']+)["']/g)) {
    const s = m[1];
    if (s.startsWith(".")) continue; // same-area relative import
    if (/^(react|node:)/.test(s)) continue;
    specifiers.add(s);
  }
}

// Map a workspace specifier (@scope/pkg/sub/path) onto files in this repo.
const repoRoot = git(["rev-parse", "--show-toplevel"]);
const pkgDirs = [];
for (const base of ["packages", "apps", "libs"]) {
  const b = join(repoRoot, base);
  if (!existsSync(b)) continue;
  for (const n of readdirSync(b)) pkgDirs.push(join(b, n));
}
const localPkgs = new Map();
for (const d of pkgDirs) {
  const pj = join(d, "package.json");
  if (existsSync(pj)) {
    try {
      localPkgs.set(JSON.parse(readFileSync(pj, "utf8")).name, d);
    } catch {}
  }
}

const dataPathDirs = new Set();
for (const s of specifiers) {
  for (const [name, dir] of localPkgs) {
    if (s === name || s.startsWith(`${name}/`)) {
      const sub = s.slice(name.length).replace(/^\//, "");
      // Point at the sub-path when it names one, else the package root.
      dataPathDirs.add(sub ? join(dir, sub.split("/").slice(0, 2).join("/")) : dir);
    }
  }
}

const dirty = new Set(
  git(["status", "--short"])
    .split("\n")
    .filter(Boolean)
    .map((l) => join(repoRoot, l.slice(3).trim())),
);

const touches = (paths) => [...dirty].filter((d) => paths.some((p) => d.startsWith(p)));

const areaDirty = touches(roots.map((r) => join(repoRoot, r).replace(`${repoRoot}/${repoRoot}`, repoRoot)));
const dataDirty = touches([...dataPathDirs]);

const recent = git(["log", "--oneline", `${since}..HEAD`, "--", ...roots, ...[...dataPathDirs]])
  .split("\n")
  .filter(Boolean);

out(`area files            ${areaFiles.length}`);
out(`data-path packages    ${[...dataPathDirs].length}`);
for (const d of [...dataPathDirs].sort()) out(`  · ${d.replace(`${repoRoot}/`, "")}`);
out("");
out(`dirty in area         ${areaDirty.length ? areaDirty.join(", ") : "none"}`);
out(`dirty in data path    ${dataDirty.length ? dataDirty.join(", ") : "none"}`);
out("");
out(`commits since ${since} touching either (${recent.length}):`);
for (const c of recent.slice(0, 15)) out(`  ${c}`);

if (areaDirty.length || dataDirty.length) {
  note(
    "\nCONTENDED. Findings on this area may be stale before they are read. Pick another area, or reserve these files first.",
  );
  process.exit(1);
}
out("\nUncontended: neither the area's components nor the code it renders from is dirty.");
