# Webflow Porting Notes

Use this reference only when the source website comes from Webflow or a Webflow export/runtime.

## Source Preference

1. Live production URL for real SEO, redirects, published content, analytics, assets, and performance.
2. Webflow export or CMS/API data for structured content and original assets.
3. Webflow Designer for ambiguous interactions, hidden states, CMS bindings, components, symbols, and responsive breakpoint details.
4. Staging/design domains only when production is missing content or a newer unpublished design is intentionally authoritative.

## What To Extract

- Pages, slugs, folders, page titles, meta descriptions, Open Graph images, noindex flags, custom code, and canonical overrides.
- 301 redirects and any manual slug migration notes.
- CMS collections, field names/types, reference fields, rich text, dates, sort orders, filters, conditional visibility, and empty states.
- Components/symbols, nav/footer variants, forms, success/error states, and embedded scripts.
- Assets: original images, responsive variants, logos, favicons, webclips, Lottie JSON, videos, documents, and fonts.
- Interactions: load animations, scroll-into-view effects, parallax, sticky sections, tabs, accordions, hover states, mobile menu states, and IX2 timing/easing.

## Implementation Guidance

- Do not blindly ship exported Webflow CSS/JS as the long-term app architecture. Use it as evidence for layout, spacing, typography, and interaction behavior.
- Map repeated Webflow classes into meaningful components and design tokens.
- Rebuild Webflow interactions with the target app's native approach: CSS transitions, IntersectionObserver, Framer Motion, GSAP, or existing local animation helpers.
- Preserve CMS slugs and canonical URLs. If the target uses local content files, keep source IDs or legacy slugs in frontmatter/data for auditability.
- Preserve form intent and visible behavior, but confirm backend routing before enabling production submissions.
- Treat Webflow-generated responsive image URLs as source evidence; download or replace with owned optimized assets in the target app.

## Animation Capture Checklist

- Capture page load at 0 ms or first paint where possible.
- Capture post-load settled state after fonts, images, Lottie, and interaction scripts finish.
- Capture each distinct scroll-triggered section after it enters the viewport.
- Capture mobile breakpoint states, especially nav menu and stacked hero/CTA sections.
- Capture hover/open states for cards, tabs, accordions, dropdowns, and tool UI.
- Check `prefers-reduced-motion`; if the original ignores it, decide whether the port should improve it and document that as an intentional improvement.

## Common Gotchas

- Elements hidden by initial Webflow interaction state can look missing if screenshots are taken too early.
- Webflow staging domains can carry noindex/canonical behavior that should not be copied to production.
- Exported assets may include unused files, duplicated responsive variants, and old favicons.
- CMS rich text often contains nested embeds, manual heading levels, and inline links that need separate validation.
- Webflow forms, reCAPTCHA, site search, ecommerce, memberships, and localization do not automatically survive a static export.
- Webflow class names often encode layout accidents. Preserve the visual system, not the class taxonomy.
