#!/usr/bin/env node
// council-ledger.mjs — two-tier decision ledger for the review-council skill.
//
//   Project tier : <git-root or cwd>/council/ledger.jsonl   (full decision records)
//   Global tier  : ~/.claude/council/calibration.jsonl       (content-free signal only)
//
// Commands:
//   node council-ledger.mjs root
//   node council-ledger.mjs due                         -> decisions past revisit-date with no outcome yet
//   node council-ledger.mjs recent [n]
//   node council-ledger.mjs calibration [decision_type]
//   node council-ledger.mjs log-decision  <flags | json>
//   node council-ledger.mjs log-outcome   <flags | json>
//
// Logging accepts SIMPLE FLAGS so the model never hand-builds JSON:
//   log-decision --type pricing --question "..." --rec "..." --confidence 0.7 \
//                --kill "..." --revisit 2026-08-01 \
//                --leans "Contrarian:against,Executor:for" --guests "Pricing Strategist" --mode standard
//   log-outcome  --id <id> --outcome right --correct "Contrarian,First Principles" --notes "..."
// (A single JSON object as the arg or on stdin still works as a fallback.)

import { execSync } from "node:child_process";
import { homedir } from "node:os";
import { join, basename } from "node:path";
import { existsSync, mkdirSync, appendFileSync, readFileSync } from "node:fs";

const GLOBAL_DIR = join(homedir(), ".claude", "council");
const GLOBAL_FILE = join(GLOBAL_DIR, "calibration.jsonl");

// Calibration is suppressed until there is enough closed-loop data, so small
// samples never masquerade as authoritative signal.
const MIN_RESOLVED = 8; // total logged outcomes before any ranking is shown
const MIN_PRESENT = 3;  // per-advisor appearances before its hit-rate is shown

function projectRoot() {
  try {
    return execSync("git rev-parse --show-toplevel", {
      stdio: ["ignore", "pipe", "ignore"],
    }).toString().trim() || process.cwd();
  } catch {
    return process.cwd();
  }
}
const projectFile = () => join(projectRoot(), "council", "ledger.jsonl");
const projectId = () => basename(projectRoot());
const pad = (n) => String(n).padStart(2, "0");

function newId() {
  const d = new Date();
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  return `${stamp}-${Math.floor(Math.random() * 1e4).toString(36)}`;
}
function today() {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function readJsonl(file) {
  if (!existsSync(file)) return [];
  return readFileSync(file, "utf8").split("\n").filter(Boolean)
    .map((line) => { try { return JSON.parse(line); } catch { return null; } })
    .filter(Boolean);
}
function appendJsonl(file, record) {
  mkdirSync(join(file, ".."), { recursive: true });
  appendFileSync(file, JSON.stringify(record) + "\n");
}

// --- input: simple flags OR a JSON object (arg/stdin) -----------------------
function parseFlags(rest) {
  const raw = {};
  for (let i = 0; i < rest.length; i++) {
    if (!rest[i].startsWith("--")) continue;
    const key = rest[i].slice(2);
    raw[key] = (i + 1 < rest.length && !rest[i + 1].startsWith("--")) ? rest[++i] : "true";
  }
  const alias = { type: "decision_type", rec: "recommendation", kill: "kill_criteria", revisit: "revisit_date" };
  const o = {};
  for (const [k, v] of Object.entries(raw)) o[alias[k] || k] = v;
  if (o.confidence != null) o.confidence = Number(o.confidence);
  if (typeof o.guests === "string") o.guests = o.guests ? o.guests.split(",").map((s) => s.trim()).filter(Boolean) : [];
  if (typeof o.correct === "string") { o.advisors_correct = o.correct.split(",").map((s) => s.trim()).filter(Boolean); delete o.correct; }
  if (typeof o.leans === "string") {
    o.advisor_leans = Object.fromEntries(o.leans.split(",").map((p) => p.split(":").map((s) => s.trim())).filter((a) => a[0]));
    delete o.leans;
  }
  return o;
}
function readInput(rest) {
  if (rest.length && rest[0].startsWith("--")) return parseFlags(rest);
  if (rest.length && rest[0].trim().startsWith("{")) return JSON.parse(rest.join(" "));
  const stdin = readFileSync(0, "utf8").trim();
  if (!stdin) throw new Error("no input (use flags, a JSON arg, or stdin)");
  return JSON.parse(stdin);
}

// --- commands ---------------------------------------------------------------
function logDecision(input) {
  const id = newId();
  const ts = new Date().toISOString();
  const root = projectRoot();
  const pid = projectId();
  const advisors = [...Object.keys(input.advisor_leans || {}), ...(input.guests || [])];

  appendJsonl(projectFile(), {
    kind: "decision", id, ts, project_id: pid, project_root: root,
    decision_type: input.decision_type ?? "unspecified",
    question: input.question ?? "", recommendation: input.recommendation ?? "",
    confidence: input.confidence ?? null, kill_criteria: input.kill_criteria ?? "",
    revisit_date: input.revisit_date ?? "", advisor_leans: input.advisor_leans ?? {},
    guests: input.guests ?? [], mode: input.mode ?? "standard",
  });
  appendJsonl(GLOBAL_FILE, {
    kind: "decision", id, ts, project_id: pid,
    decision_type: input.decision_type ?? "unspecified",
    advisors, confidence: input.confidence ?? null,
  });
  process.stdout.write(JSON.stringify({ id, project_ledger: projectFile() }) + "\n");
}

function logOutcome(input) {
  if (!input.id) throw new Error("log-outcome requires --id");
  const ts = new Date().toISOString();
  const decision = readJsonl(GLOBAL_FILE).find((r) => r.kind === "decision" && r.id === input.id);
  const decisionType = decision?.decision_type ?? "unspecified";

  appendJsonl(projectFile(), {
    kind: "outcome", id: input.id, ts, outcome: input.outcome ?? "unknown",
    advisors_correct: input.advisors_correct ?? [], notes: input.notes ?? "",
  });
  appendJsonl(GLOBAL_FILE, {
    kind: "outcome", id: input.id, ts, project_id: projectId(),
    decision_type: decisionType, outcome: input.outcome ?? "unknown",
    advisors_correct: input.advisors_correct ?? [],
  });
  process.stdout.write(JSON.stringify({ ok: true, id: input.id }) + "\n");
}

function due() {
  const rows = readJsonl(projectFile());
  const resolved = new Set(rows.filter((r) => r.kind === "outcome").map((r) => r.id));
  const t = today();
  const out = rows
    .filter((r) => r.kind === "decision" && r.revisit_date && r.revisit_date <= t && !resolved.has(r.id))
    .map((d) => ({ id: d.id, decision_type: d.decision_type, recommendation: d.recommendation, revisit_date: d.revisit_date }));
  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
}

function recent(n) {
  const limit = Number(n) || 5;
  const out = readJsonl(projectFile()).filter((r) => r.kind === "decision").slice(-limit).reverse()
    .map((d) => ({ id: d.id, ts: d.ts, decision_type: d.decision_type, recommendation: d.recommendation, confidence: d.confidence, revisit_date: d.revisit_date }));
  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
}

function calibration(decisionType) {
  const rows = readJsonl(GLOBAL_FILE).filter((r) => !decisionType || r.decision_type === decisionType);
  const resolved = rows.filter((r) => r.kind === "outcome").length;
  if (resolved < MIN_RESOLVED) {
    process.stdout.write(JSON.stringify({
      decision_type: decisionType ?? "all", status: "insufficient_data", resolved, needed: MIN_RESOLVED,
      note: "Not enough closed-loop outcomes yet — calibration suppressed so small samples don't become authoritative noise. Keep logging outcomes.",
    }, null, 2) + "\n");
    return;
  }
  const stats = {};
  const touch = (name) => (stats[name] ??= { present: 0, correct: 0 });
  for (const r of rows) {
    if (r.kind === "decision") for (const a of r.advisors || []) touch(a).present += 1;
    if (r.kind === "outcome") for (const a of r.advisors_correct || []) touch(a).correct += 1;
  }
  const out = Object.entries(stats)
    .filter(([, s]) => s.present >= MIN_PRESENT)
    .map(([advisor, s]) => ({ advisor, present: s.present, correct: s.correct, hit_rate: +(s.correct / s.present).toFixed(2) }))
    .sort((a, b) => b.hit_rate - a.hit_rate);
  process.stdout.write(JSON.stringify({ decision_type: decisionType ?? "all", resolved, advisors: out }, null, 2) + "\n");
}

const [cmd, ...rest] = process.argv.slice(2);
switch (cmd) {
  case "root":
    process.stdout.write(JSON.stringify({ project_root: projectRoot(), project_id: projectId(), project_ledger: projectFile(), global_store: GLOBAL_FILE }, null, 2) + "\n");
    break;
  case "due": due(); break;
  case "recent": recent(rest[0]); break;
  case "calibration": calibration(rest[0]); break;
  case "log-decision": logDecision(readInput(rest)); break;
  case "log-outcome": logOutcome(readInput(rest)); break;
  default:
    process.stderr.write("commands: root | due | recent [n] | calibration [type] | log-decision <flags|json> | log-outcome <flags|json>\n");
    process.exit(1);
}
