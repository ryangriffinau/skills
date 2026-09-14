# Default design bar

Repo contracts win; this file is the fallback when the target repo has no `DESIGN.md`, no design-system doc, and no frontend rules in `AGENTS.md`.

- Information hierarchy first: one heading tier per section, sections in task order (choose, edit, review). No redundant controls for the same choice.
- A property is never a choice. If the domain fixes a value (a finding type has one stage), show it, do not ask for it.
- Switches for single on/off configuration choices. Checkboxes only for multi-selects and grids. A card-style choicebox for one major choice among a few named options. Select for one choice among many short options.
- No tri-state where a boolean will do. No 'use default' options.
- Never show developer values (position indexes, ids, revisions) to users. Order by drag and drop, keyboard reorder through the handle.
- No dead cells, no badges that restate state, no Edit button when the control itself is the edit.
- Plain ASD-STE100 copy on every label and help line.
