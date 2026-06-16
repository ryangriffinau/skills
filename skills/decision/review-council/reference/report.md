# Report & Transcript Output

Every session produces two files in `./council/` (create the folder if missing). Set `TS=$(date +%Y%m%d-%H%M%S)` once and reuse it for both filenames so they pair up.

```
council/council-report-<TS>.html    # visual briefing for scanning
council/council-transcript-<TS>.md  # full transcript for reference
```

The user reads the HTML; the transcript is the durable artifact. After writing the HTML, **open it** so the user sees it immediately (`open council/council-report-<TS>.html` on macOS).

## The HTML report

A single self-contained file with **inline CSS** (no external assets, no CDN). It should look like a professional briefing document — clean, not flashy.

**Contents, top to bottom:**
1. **The question** — the framed question, at the top.
2. **The chairman's verdict** — prominent, this is what most people read. Render all five verdict sections.
3. **Agreement / clash visual** — a simple, scannable visual of where advisors aligned vs diverged. A grid or a spectrum is fine (e.g. each advisor as a row, their lean as a colored pill; or a two-column agree/clash layout). Keep it clean.
4. **Collapsible per-advisor sections** — each advisor's full response in a `<details>` element, **collapsed by default** so the page isn't overwhelming.
5. **Collapsible peer-review section** — review highlights in a `<details>` element.
6. **Footer** — the timestamp and a one-line note on what was counciled.

**Styling:** white background, subtle borders, system font stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`), soft accent colors to distinguish advisor sections, generous line-height, max content width ~760px centered. Use native `<details>/<summary>` for collapsibles (no JS required). Make it readable on mobile.

## The transcript (markdown)

Complete record, in this order:
1. Original question (verbatim from the user)
2. Framed question
3. All 5 advisor responses (labeled by advisor)
4. All 5 peer reviews — **with the anonymization mapping revealed** (e.g. "Response C = The Outsider")
5. The chairman's full synthesis

This lets a future session see how the thinking evolved if the user re-runs the council after making changes.
