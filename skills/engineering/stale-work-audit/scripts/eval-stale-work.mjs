#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { auditFromSnapshot } from "./audit-work.mjs";
import { renderMarkdown } from "./render-report.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const evalPath = join(here, "../evals/evals.json");
const evals = JSON.parse(readFileSync(evalPath, "utf8"));

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function assertIncludes(text, expected, message) {
  if (!text.includes(expected)) {
    throw new Error(`${message}: missing ${expected}`);
  }
}

for (const testCase of evals.cases) {
  const report = auditFromSnapshot({
    repo: testCase.repo,
    profile: testCase.profile,
    threadText: testCase.threadText,
    snapshot: testCase.snapshot,
  });
  const firstGroup = report.groups[0];
  const firstItem = firstGroup?.items[0];
  assertEqual(firstGroup?.status, testCase.expect.status, `${testCase.name} status group`);
  assertEqual(firstItem?.status, testCase.expect.status, `${testCase.name} item status`);
  if (testCase.expect.prNumber) {
    const numbers = firstItem.prs.map((pr) => pr.number);
    if (!numbers.includes(testCase.expect.prNumber)) {
      throw new Error(`${testCase.name} expected PR ${testCase.expect.prNumber}`);
    }
  }
  const markdown = renderMarkdown(report);
  assertIncludes(markdown, testCase.expect.status, `${testCase.name} markdown status`);
  if (testCase.expect.prNumber) {
    assertIncludes(markdown, String(testCase.expect.prNumber), `${testCase.name} markdown PR`);
  }
  process.stdout.write(`ok ${testCase.name}\n`);
}
