---
name: add-prompt
status: drafting
version: 0.6.0
tags: [meta, prompts, tooling]
updated: 2026-10-14
description: Save a reusable instruction as a portable p-prefixed skill for Claude Code and Codex. Use when the user asks to add a prompt, save an instruction, or grow their prompt library. Preserve user-provided wording verbatim, publish the source, install it, and verify discovery.
---

# Add Prompt

A prompt is a skill. The `p-` prefix is a naming choice, not a separate format.
Create new workflows as `skills/<category>/p-<name>/SKILL.md` packages.
Existing files under `prompts/` await migration; edit those at their canonical
location until migrated. Do not create a second source for the same instruction.

## Steps

1. **Read the source repo's instructions and README.** Confirm the canonical
   repository, scope, name, description, and body. Default to global installation
   for this personal library unless the user requests project scope.
2. **Write the package.** Use `name` and `description` frontmatter plus the repo's
   version, maturity, tags, and date fields. The name must match the directory.
   Keep all needed references and scripts within the package.
3. **Preserve the body.** If the user provides text, save it verbatim. Preserve
   wording, order, punctuation, line breaks, and placeholders. Add metadata
   around it. Do not silently add instructions, arguments, or negative rules.
   Put optional improvements in the response after completing the request.
4. **Handle host differences honestly.** Codex CLI selects `$<name>` or `/skills`;
   the desktop app uses `@<name>`; Claude Code uses `/<name>`. A flat Markdown
   file under `~/.codex/prompts` does not register a native Codex skill. Directory
   bridges alone cannot fix that. Check supported argument and invocation policy
   metadata before adding host-specific files. If verbatim text uses unsupported
   host commands, report that limitation; do not rewrite it without authorization.
5. **Verify the source.** Parse the frontmatter, check bundled references, and
   compare a supplied body with the user's text. Run the repo's checks and update
   its catalog. Default new prompts to refining unless the user specifies otherwise.
6. **Publish.** For this library, a finalized add-prompt request includes publishing
   to remote `main`. Commit only the current request's files and catalog changes.
   Preserve unrelated work. Fetch before reconciling, retain commit ancestry, and
   never force-push or squash. If the current branch contains unrelated work,
   prepare the change on an isolated checkout based on remote `main` rather than
   pushing that branch as main. Follow branch protection if present.
7. **Install the published version.** Follow the tested CLI and Node requirements
   in README. Select this skill and the target agents explicitly:

   ```bash
   npx skills@1.7.1 add ryangriffinau/skills --skill <name> --global --agent codex claude-code --yes
   ```

   Before replacement, compare the complete installed package. Preserve edits and
   back it up outside discovery directories. Do not replace jsm or other owners'
   packages on a name match. Keep the public installer's lock and provenance.
8. **Verify the installation.** Compare all package files and resolved links with
   the published source. Verify runtime discovery where available. Distinguish
   filesystem, discovery API, and visible picker checks. A stale open session may
   need a new chat or reload; do not claim to have observed an untested picker.

For an existing legacy prompt, updating the source also updates Claude's linked
commands directory. If a native compatibility copy exists, update and verify it
too. A plain prompt cannot be passed to `skills add`; state that limitation until
its source is migrated. Keep its body portable rather than adding an absolute
path back to one machine's checkout.

## Completion

Report the published commit, native invocation, install locations, checks, and
any remaining limitation. Publishing or installing alone is not proof that a
runtime can load the workflow. Never claim completion when a required step failed.
