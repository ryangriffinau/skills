#!/usr/bin/env node
/**
 * joint-design-review static scan — deterministic design-bar sweep.
 *
 * Usage:  node static-scan.mjs <path> [<path> ...] [--exclude <substr>]... [--json]
 *         Paths may be directories or individual files, in any mix.
 * Output: JSONL findings on stdout ({check, file, line, excerpt}),
 *         summary table on stderr. Exit 0 always — hits are audit
 *         candidates for the model to verify, not a build failure.
 *
 * Every check is a cheap textual signal of a Class A candidate. The model
 * verifies each hit in context (a hex literal inside a theme/token file is
 * fine; the scan auto-skips common token file names, and --exclude handles
 * the rest).
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, sep } from "node:path";
import { note, out } from "./io.mjs";

const SOURCE_EXT = /\.(tsx|jsx|ts|js|css|vue|svelte|astro)$/;
const SKIP_DIRS = new Set([
  "node_modules", ".git", "dist", "build", ".next", ".output", ".turbo",
  "coverage", "test-results",
]);
// Token/theme sources legitimately hold raw color values.
const SKIP_FILES = /(theme|tokens?|palette)\.(css|ts|js)$|\.test\.|\.spec\.|\.stories\./;

const CHECKS = [
  {
    check: "raw-color-literal",
    why: "Semantic tokens only; raw colors freeze one theme and break the other",
    re: /#[0-9a-fA-F]{3,8}\b|rgba?\(\s*\d/,
    ext: /\.(tsx|jsx|css|vue|svelte|astro)$/,
  },
  {
    check: "transition-all",
    why: "Transition exact properties, never `all`",
    re: /transition-all|transition:\s*all/,
  },
  {
    check: "ease-in-on-ui",
    why: "ease-in starts slow and feels sluggish; use ease-out or a custom curve",
    re: /(?:^|[\s"'`])ease-in(?!-out)\b|transition[^;]{0,80}\bease-in\b(?!-out)/,
  },
  {
    check: "duration-over-300ms",
    why: "UI animations stay under 300ms",
    re: /duration-(?:[4-9]\d\d|\d{4,})\b|duration-\[(?:[4-9]\d\d|\d{4,})ms\]|(?:transition|animation)[^;]{0,60}\b(?:0?\.[4-9]\d*s|[1-9]\d*(?:\.\d+)?s|(?:[4-9]\d\d|\d{4,})ms)/,
  },
  {
    check: "scale-from-zero",
    why: "Nothing real appears from nothing; enter from scale(0.95)+opacity",
    re: /\bscale-0(?![.\d])|scale\(\s*0\s*\)/,
  },
  {
    check: "arbitrary-z-index",
    why: "Use the design system's named layers, not ad-hoc stacking",
    re: /z-\[\d+\]|z-index:\s*(?!var\()\d{2,}/,
  },
  {
    check: "px-font-size",
    why: "Type sizes come from the scale, not arbitrary px",
    re: /text-\[\d+px\]|font-size:\s*\d+px/,
    ext: /\.(tsx|jsx|vue|svelte|astro)$/,
  },
  {
    check: "window-history-back",
    why: "The router owns history; window.history bypasses blockers",
    re: /window\.history\.back/,
  },
  {
    check: "css-important",
    why: "!important is a specificity dead end",
    re: /!important/,
  },
  {
    // Class A #14 over-explanation. A UI sentence long enough that it is
    // probably explaining something the control already shows. Matches the
    // string literal wherever it sits, because prose is usually on its own
    // line inside a ternary rather than beside the element that renders it.
    check: "verbose-ui-sentence",
    why: "Over-explanation (Class A #14): a UI sentence long enough to be explaining the obvious",
    ext: /\.(tsx|jsx|vue|svelte|astro)$/,
    custom: (line) => {
      if (/^\s*(\/\/|\*|\/\*)/.test(line)) return false; // comments are not UI copy
      for (const m of line.matchAll(/"([^"\\]{40,})"/g)) {
        const text = m[1];
        if (!/[.?]$/.test(text.trim())) continue;
        if (text.split(/\s+/).length >= 12) return true;
      }
      return false;
    },
  },
  {
    // Class A #14 again: a field label above a control whose own first option
    // already says the same thing ("Status" over a select reading "Open
    // findings"; "Customer contact" over "Choose a customer contact").
    check: "label-restates-control",
    why: "Over-explanation (Class A #14): a label the control's own value already states",
    ext: /\.(tsx|jsx|vue|svelte|astro)$/,
    custom: (line, _i, all, idx) => {
      const label = line.match(/<Label[^>]*>\s*$|<Label[^>]*>\s*([A-Za-z][A-Za-z ]{2,24}?)\s*</);
      const text = (label?.[1] ?? all[idx + 1] ?? "").trim();
      if (!/^[A-Za-z][A-Za-z ]{2,24}$/.test(text)) return false;
      const head = text.split(/\s+/)[0].toLowerCase();
      if (head.length < 4) return false;
      const ahead = all.slice(idx + 1, idx + 14).join(" ").toLowerCase();
      // the control's placeholder/first option repeats the label's leading word
      return new RegExp(`(placeholder=|>)\\s*["']?(choose|select|all|pick)?\\s*(an?\\s+)?${head}`).test(
        ahead,
      );
    },
  },
];

const args = process.argv.slice(2);
const roots = [];
const excludes = [];
let asJson = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--exclude") excludes.push(args[++i]);
  else if (args[i] === "--json") asJson = true;
  else roots.push(args[i]);
}
if (roots.length === 0) {
  note("usage: static-scan.mjs <path> [<path> ...] [--exclude <substr>] [--json]");
  process.exit(2);
}

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    let st;
    try {
      st = statSync(path);
    } catch {
      continue;
    }
    if (st.isDirectory()) {
      if (!SKIP_DIRS.has(name)) yield* walk(path);
    } else if (SOURCE_EXT.test(name)) {
      yield path;
    }
  }
}

// Roots may be directories OR files. A missing/unreadable root is a warning,
// never a crash — an area routinely mixes `quality/` with `quality.tsx`.
function* resolveRoots(list) {
  for (const root of list) {
    let st;
    try {
      st = statSync(root);
    } catch {
      skipped.push(`${root} (not found)`);
      continue;
    }
    if (st.isDirectory()) yield* walk(root);
    else if (SOURCE_EXT.test(root)) yield root;
    else skipped.push(`${root} (unsupported extension)`);
  }
}

const skipped = [];
const counts = new Map(CHECKS.map((c) => [c.check, 0]));
let files = 0;

for (const file of resolveRoots(roots)) {
  if (SKIP_FILES.test(file.split(sep).join("/"))) continue;
  if (excludes.some((x) => file.includes(x))) continue;
  files++;
  const lines = readFileSync(file, "utf8").split("\n");
  for (const c of CHECKS) {
    if (c.ext && !c.ext.test(file)) continue;
    lines.forEach((text, i) => {
      const hit = c.custom ? c.custom(text, i, lines, i) : c.re.test(text);
      if (!hit) return;
      counts.set(c.check, counts.get(c.check) + 1);
      out(
        JSON.stringify({ check: c.check, file, line: i + 1, excerpt: text.trim().slice(0, 160) }),
      );
    });
  }
}

if (asJson) {
  note(JSON.stringify({ files, skipped, counts: Object.fromEntries(counts) }, null, 2));
} else {
  note(`\nstatic-scan: ${files} files`);
  if (skipped.length) note(`skipped roots: ${skipped.join(", ")}`);
  note("");
  for (const c of CHECKS) {
    const n = counts.get(c.check);
    note(`  ${n === 0 ? "clear" : String(n).padStart(5)}  ${c.check} — ${c.why}`);
  }
  note("\nHits are candidates for the audit, not findings. Verify each in context.");
}
