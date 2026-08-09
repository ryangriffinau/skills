#!/usr/bin/env node
/**
 * joint-design-review capture harness.
 *
 * Captures every surface of an area at every viewport, and REFUSES to keep a
 * capture that is not of the page you asked for.
 *
 * Why the refusal matters: a stored browser session whose short-lived token has
 * expired sends the first navigation of each fresh context to the login screen,
 * while later navigations succeed. Those login-page captures look plausible and
 * get reasoned about as if they were the app. The warm-up plus the final-URL
 * assertion below is the whole defence.
 *
 *   node shoot.mjs <config.json> [--out <dir>]
 *
 * Config:
 * {
 *   "baseUrl": "http://localhost:3000",
 *   "storageState": "/abs/path/state.json",   // optional
 *   "warmup": { "path": "/home", "waitFor": "window.Clerk?.loaded === true" },
 *   "viewports": [ {"name":"desktop","width":1440,"height":900},
 *                  {"name":"mobile","width":390,"height":844} ],
 *   "surfaces": [ {"slug":"list","path":"/quality"},
 *                 {"slug":"detail","path":"/quality/{{findingId}}"} ],
 *   "vars": { "findingId": "abc123" },
 *   "theme": "light"                           // or "dark", or omit
 * }
 *
 * Prints a JSON report: per capture, the final URL, whether it matched, page
 * overflow, and any console errors. Exit 1 if any capture was rejected.
 */
import { mkdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const [configPath, ...rest] = process.argv.slice(2);
if (!configPath) {
  console.error("usage: shoot.mjs <config.json> [--out <dir>]");
  process.exit(2);
}
const cfg = JSON.parse(readFileSync(configPath, "utf8"));
const outIdx = rest.indexOf("--out");
const OUT = resolve(outIdx === -1 ? (cfg.out ?? "./screenshots") : rest[outIdx + 1]);
mkdirSync(OUT, { recursive: true });

// Playwright is resolved from the project under review, not vendored here.
let chromium;
try {
  ({ chromium } = await import("@playwright/test"));
} catch {
  console.error(
    "Playwright not resolvable. Run this from a directory where @playwright/test is installed.",
  );
  process.exit(2);
}

const subst = (s) =>
  s.replace(/\{\{(\w+)\}\}/g, (_, k) => {
    const v = cfg.vars?.[k];
    if (v === undefined) throw new Error(`config.vars.${k} is not set but "{{${k}}}" is used`);
    return v;
  });

const browser = await chromium.launch();
const report = [];
let rejected = 0;

for (const vp of cfg.viewports ?? [{ name: "desktop", width: 1440, height: 900 }]) {
  const context = await browser.newContext({
    ...(cfg.storageState ? { storageState: cfg.storageState } : {}),
    viewport: { width: vp.width, height: vp.height },
    deviceScaleFactor: 2,
    ...(cfg.theme ? { colorScheme: cfg.theme } : {}),
  });
  const page = await context.newPage();
  const errors = [];
  page.on("console", (m) => m.type() === "error" && errors.push(m.text().slice(0, 200)));
  page.on("pageerror", (e) => errors.push(`pageerror: ${String(e).slice(0, 200)}`));

  // --- warm-up. Never skip: this is what stops login-page captures.
  if (cfg.warmup) {
    const url = new URL(cfg.warmup.path, cfg.baseUrl).toString();
    await page.goto(url, { waitUntil: "networkidle", timeout: 30_000 });
    if (cfg.warmup.waitFor) {
      try {
        await page.waitForFunction(cfg.warmup.waitFor, { timeout: 20_000 });
      } catch {
        console.error(`warm-up predicate never became true at ${url}`);
      }
    }
    if (!page.url().includes(cfg.warmup.path)) {
      console.error(
        `WARM-UP FAILED: ${url} redirected to ${page.url()}. The session is probably stale — refresh it before capturing.`,
      );
      await browser.close();
      process.exit(1);
    }
  }

  for (const s of cfg.surfaces) {
    const path = subst(s.path);
    const url = new URL(path, cfg.baseUrl).toString();
    let navError = null;
    try {
      await page.goto(url, { waitUntil: "networkidle", timeout: 30_000 });
    } catch (e) {
      navError = String(e).slice(0, 140);
    }
    await page.waitForTimeout(s.settleMs ?? 1200);

    const finalUrl = page.url();
    // The assertion: did we land where we asked? An expectRedirect surface
    // (a permission test, say) declares its own expected destination.
    const expected = s.expectUrl ? subst(s.expectUrl) : path;
    const matched = new URL(finalUrl).pathname.startsWith(new URL(expected, cfg.baseUrl).pathname);

    const file = join(OUT, `${s.slug}-${vp.name}${cfg.theme === "dark" ? "-dark" : ""}.png`);
    await page.screenshot({ path: file, fullPage: s.fullPage !== false });

    const metrics = await page.evaluate(() => ({
      scrollW: document.documentElement.scrollWidth,
      clientW: document.documentElement.clientWidth,
      text: document.body.innerText.slice(0, 160).replace(/\s+/g, " "),
    }));

    if (!matched) rejected++;
    report.push({
      surface: s.slug,
      viewport: vp.name,
      requested: path,
      finalUrl,
      matched,
      navError,
      pageOverflow: metrics.scrollW > metrics.clientW ? `${metrics.scrollW}>${metrics.clientW}` : false,
      firstText: metrics.text,
      file,
    });
    console.error(
      `[${vp.name}] ${s.slug.padEnd(18)} ${matched ? "ok " : "REJECTED"} -> ${finalUrl}`,
    );
  }
  if (errors.length) {
    report.push({ viewport: vp.name, consoleErrors: [...new Set(errors)].slice(0, 10) });
  }
  await context.close();
}

await browser.close();
console.log(JSON.stringify(report, null, 2));
if (rejected) {
  console.error(
    `\n${rejected} capture(s) landed somewhere other than the requested page. Do not reason about those images.`,
  );
  process.exit(1);
}
