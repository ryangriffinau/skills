#!/usr/bin/env node
/**
 * joint-design-review static scan — deterministic design-bar sweep.
 *
 * Usage:  node static-scan.mjs <dir> [<dir> ...] [--exclude <substr>]...
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
];

const args = process.argv.slice(2);
const roots = [];
const excludes = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--exclude") excludes.push(args[++i]);
  else roots.push(args[i]);
}
if (roots.length === 0) {
  console.error("usage: static-scan.mjs <dir> [<dir> ...] [--exclude <substr>]");
  process.exit(2);
}

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (!SKIP_DIRS.has(name)) yield* walk(path);
    } else if (SOURCE_EXT.test(name)) {
      yield path;
    }
  }
}

const counts = new Map(CHECKS.map((c) => [c.check, 0]));
let files = 0;
for (const root of roots) {
  for (const file of walk(root)) {
    if (SKIP_FILES.test(file.split(sep).join("/"))) continue;
    if (excludes.some((x) => file.includes(x))) continue;
    files++;
    const lines = readFileSync(file, "utf8").split("\n");
    for (const c of CHECKS) {
      if (c.ext && !c.ext.test(file)) continue;
      lines.forEach((text, i) => {
        if (c.re.test(text)) {
          counts.set(c.check, counts.get(c.check) + 1);
          console.log(
            JSON.stringify({ check: c.check, file, line: i + 1, excerpt: text.trim().slice(0, 160) }),
          );
        }
      });
    }
  }
}

console.error(`\nstatic-scan: ${files} files\n`);
for (const c of CHECKS) {
  const n = counts.get(c.check);
  console.error(`  ${n === 0 ? "clear" : String(n).padStart(5)}  ${c.check} — ${c.why}`);
}
console.error(
  "\nHits are candidates for the audit, not findings. Verify each in context.",
);
