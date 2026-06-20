#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { basename, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const STATUSES = ["Done", "Done, deploy unverified", "Needs port", "Superseded", "Active", "Blocked", "Wrong repo / deprecated source", "Unknown"];

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[index + 1] && !argv[index + 1].startsWith("--") ? argv[index + 1] : "true";
    args[key] = value;
    if (value !== "true") index += 1;
  }
  return args;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function safeRead(path) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

function runGit(repo, args) {
  try {
    return execFileSync("git", ["-C", repo, ...args], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch {
    return "";
  }
}

function normalizePath(path, cwd) {
  if (!path) return null;
  return isAbsolute(path) ? path : resolve(cwd, path);
}

function discoverProfile(repo) {
  const remote = runGit(repo, ["remote", "get-url", "origin"]);
  return {
    version: 1,
    projectName: basename(repo),
    repos: {
      canonical: remote ? [{ path: repo, remote }] : [{ path: repo }],
      deprecated: [],
    },
    branches: {
      primary: "main",
      integration: null,
      release: [],
    },
    docs: {
      contextFiles: ["AGENTS.md", "CLAUDE.md", "README.md"],
      patterns: ["docs/**"],
    },
    pullRequests: { sources: [] },
    issues: { sources: [] },
    deployments: { sources: [] },
    externalThreads: { sources: [] },
    report: {
      verbosity: "concise",
      includeGraph: true,
      includeUnknowns: true,
    },
  };
}

function loadProfile(profilePath, repo) {
  if (profilePath && existsSync(profilePath)) {
    return readJson(profilePath);
  }
  return discoverProfile(repo);
}

function extractThreadSignals(threadText) {
  const prUrls = Array.from(threadText.matchAll(/https:\/\/github\.com\/([^/\s]+\/[^/\s]+)\/pull\/(\d+)/g)).map(
    (match) => ({
      repo: match[1],
      number: Number(match[2]),
      url: match[0],
    })
  );
  const prNumbers = Array.from(threadText.matchAll(/(?:PR|pull request)\s*#?(\d+)/gi)).map((match) =>
    Number(match[1])
  );
  const commits = Array.from(threadText.matchAll(/\b[0-9a-f]{7,40}\b/gi)).map((match) => match[0]);
  const branches = Array.from(
    threadText.matchAll(/\b(?:branch|head|base)\s+([A-Za-z0-9._/-]{3,})\b/gi)
  ).map((match) => match[1]);
  const keywords = Array.from(
    new Set(
      threadText
        .toLowerCase()
        .replace(/https?:\/\/\S+/g, " ")
        .replace(/[^a-z0-9/-]+/g, " ")
        .split(/\s+/)
        .filter((word) => word.length >= 5)
        .slice(0, 40)
    )
  );
  return { prUrls, prNumbers, commits, branches, keywords };
}

function addNode(graph, node) {
  if (!graph.nodes.some((existing) => existing.id === node.id)) graph.nodes.push(node);
}

function addEdge(graph, edge) {
  graph.edges.push(edge);
}

function addClaim(graph, claim) {
  graph.claims.push(claim);
}

function collectGitEvidence(repo, graph) {
  const branch = runGit(repo, ["branch", "--show-current"]);
  const status = runGit(repo, ["status", "--short"]);
  const remote = runGit(repo, ["remote", "get-url", "origin"]);
  const head = runGit(repo, ["rev-parse", "--short=12", "HEAD"]);
  addNode(graph, { id: `repo:${repo}`, type: "repo", label: repo });
  if (branch) {
    addNode(graph, { id: `branch:${branch}`, type: "branch", label: branch });
    addEdge(graph, { from: `repo:${repo}`, to: `branch:${branch}`, type: "has-current-branch" });
  }
  if (head) {
    addNode(graph, { id: `commit:${head}`, type: "commit", label: head });
    addEdge(graph, { from: `branch:${branch || "unknown"}`, to: `commit:${head}`, type: "points-at" });
  }
  addClaim(graph, {
    id: "claim:git-state",
    kind: "git",
    summary: `Repo ${basename(repo)} is on ${branch || "unknown branch"}${status ? " with local changes" : " with clean status"}.`,
    source: "git",
    strength: "strong",
    confidence: branch ? "high" : "medium",
    links: remote ? [{ label: "origin", href: remote }] : [],
  });
  return { branch, status, remote, head };
}

function isDeprecatedRepo(repo, profile) {
  const deprecated = profile.repos?.deprecated ?? [];
  return deprecated.some((entry) => {
    const entryPath = entry.path ? resolve(entry.path) : null;
    return entryPath === resolve(repo);
  });
}

function collectDeprecatedEvidence(repo, profile, graph) {
  if (!isDeprecatedRepo(repo, profile)) {
    return false;
  }
  const canonical = profile.repos?.canonical ?? [];
  addClaim(graph, {
    id: "claim:deprecated-repo",
    kind: "repo-authority",
    summary: "The audited repo is configured as deprecated or non-authoritative.",
    source: "profile",
    strength: "strong",
    confidence: "high",
    links: canonical.map((entry) => ({ label: entry.path || entry.remote || "canonical repo", href: entry.remote || entry.path })),
  });
  return true;
}

function listFiles(root, maxFiles = 400) {
  const files = [];
  function walk(dir) {
    if (files.length >= maxFiles) return;
    let entries = [];
    try {
      entries = readdirSync(dir);
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry === ".git" || entry === "node_modules") continue;
      const path = join(dir, entry);
      let stat;
      try {
        stat = statSync(path);
      } catch {
        continue;
      }
      if (stat.isDirectory()) {
        walk(path);
      } else if (stat.isFile()) {
        files.push(path);
      }
      if (files.length >= maxFiles) return;
    }
  }
  walk(root);
  return files;
}

function matchesDocPattern(repo, file, patterns) {
  const relative = file.slice(repo.length + 1);
  return patterns.some((pattern) => {
    if (pattern.endsWith("/**")) return relative.startsWith(pattern.slice(0, -3));
    return relative === pattern || relative.endsWith(pattern);
  });
}

function collectDocEvidence(repo, profile, signals, graph) {
  const contextFiles = profile.docs?.contextFiles ?? ["AGENTS.md", "CLAUDE.md", "README.md"];
  const patterns = [...contextFiles, ...(profile.docs?.patterns ?? [])];
  const files = listFiles(repo).filter((file) => matchesDocPattern(repo, file, patterns));
  const keywordMatches = [];
  for (const file of files.slice(0, 200)) {
    const text = safeRead(file).toLowerCase();
    const hits = signals.keywords.filter((keyword) => text.includes(keyword)).slice(0, 5);
    if (hits.length > 0) {
      keywordMatches.push({ file, hits });
      addNode(graph, { id: `doc:${file}`, type: "doc", label: file });
      addClaim(graph, {
        id: `claim:doc:${keywordMatches.length}`,
        kind: "doc-match",
        summary: `Docs mention ${hits.join(", ")}.`,
        source: "docs",
        strength: "medium",
        confidence: "medium",
        links: [{ label: file, href: file }],
      });
    }
  }
  return keywordMatches;
}

function collectThreadEvidence(signals, graph) {
  addNode(graph, { id: "thread:input", type: "thread", label: "supplied thread" });
  for (const pr of signals.prUrls) {
    const id = `pr:${pr.repo}#${pr.number}`;
    addNode(graph, { id, type: "pr", label: `${pr.repo}#${pr.number}`, url: pr.url });
    addEdge(graph, { from: "thread:input", to: id, type: "mentions" });
  }
  for (const commit of signals.commits) {
    addNode(graph, { id: `commit:${commit}`, type: "commit", label: commit });
    addEdge(graph, { from: "thread:input", to: `commit:${commit}`, type: "mentions" });
  }
  addClaim(graph, {
    id: "claim:thread-signals",
    kind: "thread",
    summary: `Thread signals: ${signals.prUrls.length} PR URL(s), ${signals.commits.length} commit(s), ${signals.keywords.length} keyword(s).`,
    source: "thread-text",
    strength: "weak",
    confidence: "low",
    links: signals.prUrls.map((pr) => ({ label: `${pr.repo}#${pr.number}`, href: pr.url })),
  });
}

function collectConfiguredPrEvidence(profile, signals, graph) {
  const profilePrs = profile.pullRequests?.known ?? [];
  const matched = [];
  for (const pr of profilePrs) {
    const direct = signals.prUrls.some((signal) => signal.number === pr.number && (!pr.repo || signal.repo === pr.repo));
    const equivalent = signals.keywords.some((keyword) => `${pr.title || ""} ${pr.branch || ""}`.toLowerCase().includes(keyword));
    if (direct || equivalent || pr.supersedesThread) {
      matched.push(pr);
      const id = `pr:${pr.repo || "unknown"}#${pr.number}`;
      addNode(graph, {
        id,
        type: "pr",
        label: `${pr.repo || "unknown"}#${pr.number}`,
        url: pr.url,
        state: pr.state,
      });
      addClaim(graph, {
        id: `claim:pr:${matched.length}`,
        kind: direct ? "direct-pr" : "equivalent-pr",
        summary: `${direct ? "Direct" : "Equivalent"} PR ${pr.number} is ${pr.state || "known"}.`,
        source: "profile-pr-source",
        strength: direct ? "strong" : "medium",
        confidence: direct ? "high" : "medium",
        links: pr.url ? [{ label: `PR ${pr.number}`, href: pr.url }] : [],
      });
    }
  }
  return matched;
}

function collectSkippedSources(profile, graph) {
  const configured = [
    ...(profile.pullRequests?.sources ?? []),
    ...(profile.issues?.sources ?? []),
    ...(profile.deployments?.sources ?? []),
    ...(profile.externalThreads?.sources ?? []),
  ];
  configured
    .filter((source) => source.enabled === false)
    .forEach((source, index) => {
      addClaim(graph, {
        id: `claim:source-disabled:${index}`,
        kind: "source-disabled",
        summary: `${source.type} source is disabled in the local profile.`,
        source: "profile",
        strength: "weak",
        confidence: "high",
        links: [],
      });
    });
}

function classifyItem({ repoDeprecated, prMatches, docMatches, signals, graph }) {
  const directThreadPrs = signals.prUrls.map((pr) => ({ number: pr.number, repo: pr.repo, title: null, state: "mentioned", url: pr.url }));
  const matchedPrs = prMatches.map((pr) => ({ number: pr.number, repo: pr.repo, title: pr.title, state: pr.state, url: pr.url }));
  const prKeys = new Set();
  const prs = [...matchedPrs, ...directThreadPrs].filter((pr) => {
    const key = `${pr.repo || "unknown"}#${pr.number}`;
    if (prKeys.has(key)) {
      return false;
    }
    prKeys.add(key);
    return true;
  });
  if (repoDeprecated) {
    return {
      id: "item-1",
      title: "Supplied work context",
      status: "Wrong repo / deprecated source",
      confidence: "high",
      reason: "The audited repo is configured as deprecated or non-authoritative.",
      prs,
      strongestEvidence: ["claim:deprecated-repo"],
      nextAction: "Audit the canonical repo before deciding whether anything needs porting.",
    };
  }
  const mergedPr = prMatches.find((pr) => pr.state === "merged");
  if (mergedPr) {
    const deploymentKnown = graph.claims.some((claim) => claim.kind === "deployment" && claim.confidence !== "low");
    return {
      id: "item-1",
      title: mergedPr.title || "Supplied work context",
      status: deploymentKnown ? "Done" : "Done, deploy unverified",
      confidence: "medium",
      reason: `Matching PR ${mergedPr.number} is merged${deploymentKnown ? " and deployment evidence exists" : ", but deployment evidence was not proven"}.`,
      prs,
      strongestEvidence: [`claim:pr:${prMatches.indexOf(mergedPr) + 1}`],
      nextAction: deploymentKnown ? "No implementation action unless product review finds a gap." : "Verify deployment/release state if it matters.",
    };
  }
  const openPr = prMatches.find((pr) => pr.state === "open");
  if (openPr) {
    return {
      id: "item-1",
      title: openPr.title || "Supplied work context",
      status: "Active",
      confidence: "medium",
      reason: `Matching PR ${openPr.number} is still open.`,
      prs,
      strongestEvidence: [`claim:pr:${prMatches.indexOf(openPr) + 1}`],
      nextAction: "Review the open PR before closing or porting anything.",
    };
  }
  const closedPr = prMatches.find((pr) => pr.state === "closed" || pr.supersedesThread);
  if (closedPr) {
    return {
      id: "item-1",
      title: closedPr.title || "Supplied work context",
      status: "Superseded",
      confidence: "medium",
      reason: `Equivalent PR ${closedPr.number} indicates the older work was closed or superseded.`,
      prs,
      strongestEvidence: [`claim:pr:${prMatches.indexOf(closedPr) + 1}`],
      nextAction: "Use the newer PR or current canonical repo as the review target.",
    };
  }
  if (docMatches.length > 0 && signals.keywords.length > 0) {
    return {
      id: "item-1",
      title: "Supplied work context",
      status: "Unknown",
      confidence: "low",
      reason: prs.length > 0 ? "A PR was mentioned, but its state was not resolved and docs only provide weak corroboration." : "Docs mention related terms, but no decisive PR, repo, or deployment evidence was found.",
      prs,
      strongestEvidence: ["claim:doc:1"],
      nextAction: prs.length > 0 ? "Resolve the mentioned PR through a configured PR source." : "Search configured PR or issue sources, or provide a branch/PR/deployment link.",
    };
  }
  return {
    id: "item-1",
    title: "Supplied work context",
    status: "Unknown",
    confidence: "low",
    reason: prs.length > 0 ? "A PR was mentioned, but no configured source proved its state or relationship." : "The audit found no decisive canonical evidence.",
    prs,
    strongestEvidence: ["claim:git-state", "claim:thread-signals"],
    nextAction: prs.length > 0 ? "Configure a PR source or inspect the mentioned PR directly." : "Provide stronger identifiers or initialize more sources in the profile.",
  };
}

function groupItems(items) {
  const groups = STATUSES.map((status) => ({ status, items: items.filter((item) => item.status === status) })).filter((group) => group.items.length > 0);
  const counts = Object.fromEntries(STATUSES.map((status) => [status, items.filter((item) => item.status === status).length]));
  return { groups, counts };
}

export function auditFromSnapshot({ repo, profile, threadText = "", snapshot = null }) {
  const graph = { nodes: [], edges: [], claims: [] };
  const signals = extractThreadSignals(threadText);
  collectThreadEvidence(signals, graph);
  const gitState = snapshot?.git ?? collectGitEvidence(repo, graph);
  if (snapshot?.git) {
    addClaim(graph, {
      id: "claim:git-state",
      kind: "git",
      summary: `Snapshot repo is on ${gitState.branch || "unknown branch"}.`,
      source: "fixture",
      strength: "strong",
      confidence: "medium",
      links: [],
    });
  }
  const repoDeprecated = snapshot?.repoDeprecated ?? collectDeprecatedEvidence(repo, profile, graph);
  const docMatches = snapshot?.docMatches ?? collectDocEvidence(repo, profile, signals, graph);
  const prMatches = snapshot?.prMatches ?? collectConfiguredPrEvidence(profile, signals, graph);
  if (snapshot?.prMatches) {
    snapshot.prMatches.forEach((pr, index) => {
      addClaim(graph, {
        id: `claim:pr:${index + 1}`,
        kind: pr.direct ? "direct-pr" : "equivalent-pr",
        summary: `${pr.direct ? "Direct" : "Equivalent"} PR ${pr.number} is ${pr.state || "known"}.`,
        source: "fixture",
        strength: pr.direct ? "strong" : "medium",
        confidence: pr.direct ? "high" : "medium",
        links: pr.url ? [{ label: `PR ${pr.number}`, href: pr.url }] : [],
      });
    });
  }
  collectSkippedSources(profile, graph);
  const item = classifyItem({ repoDeprecated, prMatches, docMatches, signals, graph });
  const { groups, counts } = groupItems([item]);
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    profile: {
      projectName: profile.projectName || basename(repo),
    },
    summary: {
      headline: `${item.status}: ${item.reason}`,
      counts,
    },
    groups,
    graph,
    unknowns: item.status === "Unknown" ? [item.reason] : [],
    decisions: [item.nextAction],
    links: [
      ...graph.claims.flatMap((claim) => claim.links ?? []),
      ...item.prs.filter((pr) => pr.url).map((pr) => ({ label: `PR ${pr.number}`, href: pr.url })),
    ],
  };
}

export function main(argv = process.argv.slice(2), cwd = process.cwd()) {
  const args = parseArgs(argv);
  const repo = normalizePath(args.repo || cwd, cwd);
  const profilePath = normalizePath(args.profile, cwd);
  const threadPath = normalizePath(args.thread, cwd);
  const profile = loadProfile(profilePath, repo);
  const threadText = threadPath ? safeRead(threadPath) : args.text || "";
  const report = auditFromSnapshot({ repo, profile, threadText });
  const json = `${JSON.stringify(report, null, 2)}\n`;
  if (args.out) {
    writeFileSync(normalizePath(args.out, cwd), json);
  } else {
    process.stdout.write(json);
  }
}

const isCli = process.argv[1] === fileURLToPath(import.meta.url);
if (isCli) {
  main();
}
