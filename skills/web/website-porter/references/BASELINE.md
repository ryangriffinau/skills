# Baseline Evidence

Use this reference while running the source-site and target-site benchmarks for a website port. The output should be evidence the next agent can trust, not a narrative guess.

## Tool Order

1. **Squirrelscan** (external/optional — the `audit-website` skill and `squirrel` CLI are installed separately; skip this tool if you don't have them)
   - If available, load/use the `audit-website` skill.
   - Confirm with `squirrel --version`.
   - Start with quick or surface coverage:
     ```bash
     squirrel audit https://example.com -C quick --format llm
     squirrel audit https://example.com -C surface -m 200 --format llm
     ```
   - Use full coverage before launch when the source site has many unique routes or SEO risk:
     ```bash
     squirrel audit https://example.com -C full -m 500 --format llm
     ```
   - Save audit IDs and exported LLM reports in `docs/verification/`.

2. **Lighthouse And PageSpeed**
   - Benchmark homepage plus each unique template type: marketing page, blog index, blog detail, tools page, tool detail, contact/demo form, legal pages, and any high-value SEO landing page.
   - Capture mobile and desktop scores where possible.
   - Prefer local Lighthouse CLI when available; otherwise use PageSpeed Insights or browser DevTools evidence.
   - Record the environment: URL, date, network/throttling mode, device mode, and whether the result came from lab data or field data.

3. **Browser Visual Evidence**
   - Capture desktop and mobile screenshots for key templates.
   - Wait for fonts/assets to load.
   - For animation-heavy pages, capture at least: initial render, post-load settled state, first scroll-triggered state, deep scroll state, mobile navigation, hover/open states where meaningful, and reduced-motion behavior if implemented.
   - Include console and network error checks.

4. **HTTP, SEO, And Crawlability**
   - Record final status code, redirect chain, canonical URL, title, description, H1, robots meta, Open Graph/Twitter tags, hreflang if present, and JSON-LD for every important route/template.
   - Fetch and preserve behavior for `/robots.txt`, `/sitemap.xml`, and any nested sitemaps.
   - Identify indexable routes, noindex routes, 404 behavior, trailing-slash behavior, and www/apex redirect behavior.

5. **Content And Data**
   - Inventory navigation, footer, page copy, CTAs, forms, blog posts, authors, categories/tags, recommendations/tools, testimonials, logos, FAQ items, and legal content.
   - For each collection, record source fields, target schema/file, slug, canonical URL, images, alt text, dates, sort order, related content, and migration status.

6. **Assets And Brand**
   - Inventory fonts, favicons/app icons, social images, logos, illustrations, photos, videos, Lottie files, PDFs, downloadable files, and third-party embeds.
   - Record asset source, target path, dimensions, format, optimization status, and any license/ownership concern.
   - Verify favicon and social preview output separately; small icons often fail even when the page design looks correct.

7. **Integrations**
   - Inventory analytics, pixels, tag managers, chat widgets, forms, scheduling embeds, newsletters, maps, payment links, login/app links, and AI/tool endpoints.
   - Do not submit live production forms unless the user explicitly approves. Inspect form actions and reproduce behavior in a safe target.

8. **Deployment And Cutover**
   - Record current host, DNS provider, nameservers, apex/www records, redirects, TLS issuer, CDN/proxy behavior, cache headers, security headers, and rollback path.
   - For the target platform, document exact required DNS records and whether proxying is supported or discouraged.

## Comparison Table

For each major route/template, maintain a table with:

| Area | Source Evidence | Target Evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| Route/status | URL, status, redirects | Preview/prod URL, status | pass/fail/deferred | |
| Metadata | title, description, canonical, OG | target values | pass/fail/deferred | |
| Content | source section list | target section list | pass/fail/deferred | |
| Visual | screenshot path | screenshot path | pass/fail/deferred | |
| Motion | states captured | states captured | pass/fail/deferred | |
| Performance | LH/PageSpeed/squirrel scores | target scores | pass/fail/deferred | |

## Hard Gates

- No indexable source route is missing without a redirect or approved omission.
- No SEO-critical metadata regression is left undocumented.
- No production-only dependency is silently stubbed.
- No unverified DNS/cutover assumption is presented as complete.
- No animation-heavy page is verified from a single static screenshot.
