# Deprecated skills

Kept for history and for lifting ideas. Archived packages use `RETIRED.md`, not
`SKILL.md`, so recursive skill discovery cannot reinstall them. They are not
tested by CI or listed in the active catalog. Moving source does not uninstall
an existing copy; installation cleanup must verify ownership and preserve edits.
Active workflows must not depend on this archive.

| Skill | Deprecated | Replaced by | Why |
| --- | --- | --- | --- |
| `flywheel-conductor` | 2026-09-24 | `prompts/p-flywheel-conductor-jsm.md` | Swarms are driven only through the jsm skill set (`/ntm`, `/vibing-with-ntm`, `/beads-br`, `/beads-bv`). Two conductors meant two places for every rule; the non-jsm fallback was the one nobody ran. |
| `project-vision` | 2026-10-14 | None specified | Retired at the owner's request; preserve existing project `VISION.md` files. |
| `flywheel-local-launcher` | 2026-10-14 | jsm's `ntm` and `vibing-with-ntm` skills | Use the maintained jsm workflows. Archived setup reference includes recovered installed-only model defaults. Existing project helpers require their own migration; this archive is not an active dependency. |
| `pr-closeout` | 2026-10-14 | None specified | Retired at the owner's request. |
| `p-agent-swarm-launcher` | 2026-10-14 | `p-flywheel-conductor-jsm` and jsm skills | Use the current conductor and native coordination workflow. |
| `p-install-agent-skill` | 2026-10-14 | Repository README install instructions | Old prompt duplicated installation behavior and obsolete bridges. |

Renames: `goal-plan` → `write-goal`; `engineering-review` → `codebase-benchmark`;
`p-pre-mortem` → `p-premortem-general`; `p-premortem-planner` → `p-premortem-spec`.
These remain active under their new names. The benchmark skill explains how to
migrate its profile without losing review history.
