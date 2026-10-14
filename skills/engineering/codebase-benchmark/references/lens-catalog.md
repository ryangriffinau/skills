# Lens Catalog

A **lens** is one engineering-practice dimension graded each run. Each lens defines *what it inspects*, its *measurable signals* (cheap, repeatable — feed from `collect-metrics.sh` where possible), and *grade anchors*. The default set below is stack-agnostic; the consuming repo's profile adds/weights lenses and supplies repo-specific signals (e.g. Convex index coverage, design-token policy).

A lens grade is only as good as its evidence. Prefer **measured violations of a rule the repo states about itself** (file-size cap, "no `any`", design-token policy) over generic opinion. Always attach `path:line`.

## Default lenses

### 1. Security & secrets
- **Inspects:** authn/authz wiring, secret handling, input validation at trust boundaries, dependency advisories, SSRF/injection surfaces.
- **Signals:** `pnpm audit` critical/high count (triaged runtime-vs-dev, reachable-vs-not); hardcoded-secret greps; unauthenticated mutation/route count; missing input validation at boundaries.
- **Anchors:** **A** = 0 reachable critical/high, secrets externalized, boundaries validated. **C** = unresolved high-severity reachable advisories or an unauthenticated sensitive surface. **F** = known-exploitable path in production.

### 2. Multi-tenancy / data isolation
- **Inspects:** whether tenant/account scoping is *code-enforced* vs operational; cross-tenant read/write paths; object-store key namespacing.
- **Signals:** queries missing a tenant predicate; shared resources keyed without tenant id; auth context threaded to the data layer.
- **Anchors:** **A** = identity asserted in the data layer, every tenant-scoped query filtered, keys namespaced. **C** = isolation correct but operational-only (one missed filter = cross-tenant leak). **F** = demonstrated cross-tenant access.

### 3. Architecture & layering
- **Inspects:** module/package boundaries, layer-inversion (db→api, ui→db), service-layer adoption, in-flight migration coherence.
- **Signals:** import-direction violations; business logic in route/handler files; % of routes routed through the service layer; stale dual-stack (e.g. mid-migration ORM + new backend coexisting).
- **Anchors:** **A** = boundaries clean, service layer consistent. **B** = mostly intact with named inversions. **C** = boundaries routinely crossed / migration stalled mid-flight.

### 4. Type safety
- **Inspects:** escape hatches vs the repo's stated type policy; boundary validation (Zod/schema at entry points); response/contract typing.
- **Signals:** `any` count, `as` assertion count, `@ts-ignore`/`-nocheck`/`-expect-error` count, non-null `!` count, `strict`/`noUncheckedIndexedAccess` settings, % of API responses with explicit (non-`dict`/`object`) models.
- **Anchors:** **A** = strict on, ~0 escape hatches, validated boundaries. **C** = escape hatches common or the type net excludes high-risk surfaces. Grade *relative to the repo's declared rule* — a repo that bans `any` but carries hundreds of them is failing its own bar.

### 5. Testing rigor
- **Inspects:** test:source ratio, real-dependency vs mock coverage, e2e/visual coverage, and **whether the gate actually runs** (coverage on the PR path, no tests that silently skip).
- **Signals:** test-file ratio; mock-DB rate; coverage floor + *where* it's enforced (PR vs post-merge); count of `skip`-on-empty / no-op tests; presence of e2e + visual-regression.
- **Anchors:** **A** = healthy ratio, real-dependency integration tests, coverage gated pre-merge, no decorative-green tests. **C** = tests exist but the gate is post-merge/advisory or key suites no-op.

### 6. Performance & data access
- **Inspects:** query patterns (N+1, full scans), index coverage, pagination, render hot paths, write amplification.
- **Signals (Convex/DB):** `.collect()` vs `.withIndex()` ratio; unindexed scans on large tables; missing pagination on list endpoints; unused/duplicate indexes. **(FE):** unmemoized hot renders, oversized client bundles.
- **Anchors:** **A** = hot paths indexed + paginated, no known N+1. **C** = full scans on growth tables or unbounded list queries.

### 7. Observability
- **Inspects:** error tracking (frontend *and* backend), structured logging, request-id/trace continuity, silent-failure paths.
- **Signals:** presence of FE error tracking; `catch {}` / swallowed errors with no logger; `console.*` used as logging in prod paths; request-id chain reaching the browser.
- **Anchors:** **A** = errors tracked end-to-end, structured logs, trace continuity. **C** = backend-only, or silent query-error swallows rendering empty-as-real-data.

### 8. Code sprawl / file size
- **Inspects:** files over the repo's stated cap; mega-file trend; god-modules.
- **Signals:** count > cap (e.g. 500 LOC); largest files; trend vs prior run; whether a size audit is wired into CI and *enforcing* vs advisory.
- **Anchors:** **A** = under cap or a *blocking* net-new gate + shrinking trend. **C** = many violators and advisory-only/absent enforcement.

### 9. DRY / separation of concerns
- **Inspects:** duplication, "handle-both-formats" antipatterns, business logic embedded in transport/handlers.
- **Signals:** dual-read patterns (`x.snake || x.camel`, `instanceof Date ? … : new Date`); copy-paste clusters; inline data access scattered across handlers.
- **Anchors:** **A** = single source of truth, transformation at one boundary. **C** = format-juggling and duplicated logic across layers.

### 10. Design tokens / frontend consistency
- **Inspects:** adherence to the repo's design-token/semantic-color policy; component reuse vs one-off styling.
- **Signals:** arbitrary-hex utility count (`text-[#…]`, `bg-[#…]`, inline `style={{color}}`); shared-component adoption %.
- **Anchors:** **A** = semantic tokens throughout, ~0 arbitrary hex. **C** = arbitrary color/styling widespread despite a stated token policy.

### 11. Accessibility
- **Inspects:** WCAG basics on user-facing surfaces (contrast, focus management, semantics, skip links), and whether a11y is tested.
- **Signals:** contrast-failing tokens; missing focus-trap on dialogs; missing landmarks/labels; presence of axe-style tests.
- **Anchors:** **A** = semantics + focus management + automated a11y tests. **C** = recurring contrast/focus gaps, no a11y tests.

### 12. Dependency health & supply chain
- **Inspects:** advisory exposure, version currency, catalog/lockfile drift, maturity policy on new deps.
- **Signals:** audit totals by severity; outdated majors; duplicate/conflicting versions; presence of a maturity-window policy (e.g. `minimumReleaseAge`).
- **Anchors:** **A** = low reachable exposure, currency policy enforced. **C** = large unresolved advisory backlog or major version sprawl.

### 13. CI/CD & build cost
- **Inspects:** quality-gate completeness, gate placement (pre- vs post-merge), build-time/cost waste, cache hygiene, PR backlog.
- **Signals:** which gates run on PRs (tsc/test/lint/coverage); build-minute trend; turbo cache hit rate; open-PR count + age.
- **Anchors:** **A** = full gate pre-merge, cached, lean. **C** = gates advisory/post-merge or runaway build cost / large stale-PR backlog.

### 14. Documentation & decision hygiene
- **Inspects:** owner-doc freshness vs behavior, ADR lifecycle health, PROGRESS.md upkeep for long-running work, customer/operational doc surface.
- **Signals:** docs touched alongside behavior changes; ADR status distribution; stale/ orphaned specs; missing runbook/API-reference/legal surfaces (for shipping products).
- **Anchors:** **A** = docs move with code, ADRs current, runbooks exist. **C** = docs drift behind behavior or decisions uncaptured.

### 15. Live-site / runtime health *(if the repo ships a site)*
- **Inspects:** the deployed site's SEO/perf/a11y/security via an external auditor (e.g. squirrelscan / `audit-website` skill).
- **Signals:** broken links, meta/SEO issues, Lighthouse-class scores, security headers.
- **Anchors:** **A** = clean audit, strong scores. **C** = recurring broken links / missing headers / poor scores.

## Tailoring

In the profile, set per-lens `weight` (for the overall grade), `enabled`, and `signals` overrides. Add repo-specific lenses (e.g. "Migration coherence" during a big cutover). Drop lenses that don't apply (e.g. lens 15 for a library). Keep the lens **set** stable across runs so trends stay comparable — when you add/remove a lens, note it in the run's SUMMARY so the trend column reads correctly.
