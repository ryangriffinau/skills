#!/usr/bin/env node
import { readFileSync } from "node:fs";

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      continue;
    }
    const key = token.slice(2);
    const value = argv[index + 1] && !argv[index + 1].startsWith("--") ? argv[index + 1] : "true";
    args[key] = value;
    if (value !== "true") {
      index += 1;
    }
  }
  return args;
}

function compactLinks(links) {
  const seen = new Set();
  return links
    .filter((link) => {
      const key = link.href || link.label;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    })
    .slice(0, 8);
}

export function renderMarkdown(report) {
  const lines = [];
  lines.push(`# Stale Work Audit`);
  lines.push("");
  lines.push(report.summary?.headline || "No summary.");
  lines.push("");
  for (const group of report.groups ?? []) {
    lines.push(`## ${group.status}`);
    for (const item of group.items) {
      const prs = item.prs?.length
        ? ` PRs: ${item.prs.map((pr) => `${pr.repo ? `${pr.repo}#` : "#"}${pr.number}${pr.state ? ` (${pr.state})` : ""}`).join(", ")}.`
        : "";
      lines.push(`- ${item.title}: ${item.reason} Confidence: ${item.confidence}.${prs} Next: ${item.nextAction}`);
    }
    lines.push("");
  }
  const links = compactLinks(report.links ?? []);
  if (links.length > 0) {
    lines.push("## Links");
    for (const link of links) {
      lines.push(`- [${link.label}](${link.href})`);
    }
    lines.push("");
  }
  if (report.unknowns?.length) {
    lines.push("## Unknowns");
    for (const unknown of report.unknowns) {
      lines.push(`- ${unknown}`);
    }
    lines.push("");
  }
  return `${lines.join("\n").trim()}\n`;
}

export function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  if (!args.input) {
    throw new Error("Missing --input");
  }
  const report = JSON.parse(readFileSync(args.input, "utf8"));
  process.stdout.write(renderMarkdown(report));
}

if (process.argv[1] && process.argv[1].endsWith("render-report.mjs")) {
  main();
}
