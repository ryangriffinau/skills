---
name: website-porter
status: refining
version: 0.9.0
tags: [web, migration, seo]
updated: 2026-06-16
description: Port existing live, CMS, or Webflow marketing websites into a full-stack app or repository while preserving SEO, content coverage, visual fidelity, animations, analytics, deployment, and cutover safety. Use when the user asks to migrate, clone, rebuild, replatform, or port a website from an existing URL, Webflow, a site builder, or another marketing stack into code.
---

# Website Porter

## Purpose

Port an existing website into a maintainable codebase without losing routes, SEO equity, content, brand fidelity, animations, analytics, or launch safety. Treat the current live website as the source of truth unless exports, design files, CMS APIs, or the user's notes are more authoritative for a specific detail.

## Operating Rules

- Start with evidence. Do not call the port complete until baseline, implementation, verification, deployment, and cutover artifacts exist.
- Prefer structured sources first: sitemap, robots, CMS export/API, Webflow export, source repo, analytics tags, and live HTML. Use visual designer tools only when live/exported evidence is ambiguous.
- Preserve URLs, status codes, canonical URLs, titles, descriptions, Open Graph/Twitter tags, JSON-LD, internal links, sitemap behavior, robots behavior, image alt text, and redirects unless the user explicitly approves changes.
- Capture motion. For animated pages, verify initial load, post-load settled state, scroll-triggered states, hover/menu states, mobile states, and reduced-motion behavior.
- Keep CMS choices conservative. For a one-off marketing port, prefer local content/data unless editing workflows or runtime data clearly justify a database or headless CMS.
- Do not change DNS, domain ownership, analytics ownership, or production traffic without explicit user approval. Prepare exact records and a rollback path.

## Workflow

1. **Intake**
   - Record source URL, desired target repo/app, deployment target, domain/cutover owner, known credentials, content freeze expectations, and explicit non-goals.
   - Ask only concrete blocking questions; otherwise make conservative assumptions and document them.

2. **Baseline The Source**
   - Use the `audit-website` squirrelscan skill when available. Run quick/surface scans first, then full coverage when launch risk or route count warrants it.
   - Gather Lighthouse/PageSpeed benchmarks for key templates on mobile and desktop.
   - Inventory routes, redirects, metadata, schema, forms, tracking scripts, fonts, assets, CMS collections, navigation, footer links, and special tools/widgets.
   - Save evidence in the target repo, typically under `docs/verification/`.
   - See [Baseline Evidence](references/BASELINE.md).

3. **Plan The Port**
   - Produce a route/content inventory and a gap list before building.
   - Split work into route shell, content/data, shared components, SEO/system defaults, visual parity, animation parity, interactive tools/forms, deployment, and cutover.
   - Decide what is exact parity, acceptable improvement, intentionally deferred, or intentionally omitted.

4. **Build**
   - Start from the best existing app/template baseline for SEO, routing, metadata, analytics, fonts, image handling, and deployment.
   - Implement shared layout and tokens before page-by-page polish.
   - Port routes and content before advanced animation. Wire redirects and metadata early so regressions are visible.
   - For AI tools/forms, stub safely if prompts, keys, or backend behavior are not yet available; document the deferred contract.

5. **Verify**
   - Compare source and target route inventories, metadata, structured data, screenshots, animation states, console errors, network errors, accessibility smoke checks, and performance benchmarks.
   - Capture desktop and mobile screenshots after assets/fonts load and at meaningful animation/scroll states.
   - Re-run squirrelscan/Lighthouse/PageSpeed on preview or production and record deltas against the source baseline.
   - Fix gaps or document user-approved differences.

6. **Deploy And Cut Over**
   - Deploy to the requested platform, attach domains if approved, and document exact DNS records, proxy requirements, verification state, and rollback steps.
   - After DNS changes, verify apex/www redirects, TLS, sitemap, robots, canonical URLs, analytics firing, forms/tools, and representative routes.

## Artifacts

Create or update these artifacts for substantial ports:

- `docs/verification/source-baseline-YYYY-MM-DD.md`
- `docs/verification/route-inventory-YYYY-MM-DD.md`
- `docs/verification/data-port-audit-YYYY-MM-DD.md`
- `docs/verification/visual-verification-YYYY-MM-DD.md`
- `docs/verification/performance-benchmark-YYYY-MM-DD.md`
- `docs/verification/production-cutover-checklist-YYYY-MM-DD.md`

## Webflow Sources

If the source website is Webflow, load [Webflow Porting Notes](references/WEBFLOW.md). Ignore that reference for non-Webflow sites unless a Webflow-style export/runtime is involved.

## Completion Criteria

- Every discovered source route is implemented, redirected, or listed as an approved omission.
- SEO-critical metadata, canonical behavior, robots/sitemap behavior, and structured data are preserved or improved intentionally.
- Key pages pass desktop/mobile visual review, including animation states and responsive navigation.
- Source-vs-target audit and performance deltas are recorded.
- Preview/production deployment is reachable and verified.
- Cutover steps, DNS records, proxy/caching notes, and rollback are documented.
