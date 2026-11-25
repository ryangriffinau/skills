# Deprecated skills

Kept for history and for lifting ideas. Archived packages use `RETIRED.md`, not
`SKILL.md`, so recursive skill discovery cannot reinstall them. They are not
tested by CI or listed in the active catalog. Moving source does not uninstall
an existing copy; installation cleanup must verify ownership and preserve edits.
Active workflows must not depend on this archive.

| Skill | Deprecated | Replaced by | Why |
| --- | --- | --- | --- |
| `flywheel-conductor` | 2026-09-24 | `skills/engineering/flywheel-conductor-jsm/SKILL.md` | Use the current conductor with jsm's `ntm`, `vibing-with-ntm`, `beads-br`, and `beads-bv` skills. |
| `project-vision` | 2026-10-14 | None specified | Retired at the owner's request; preserve existing project `VISION.md` files. |
| `flywheel-local-launcher` | 2026-10-14 | jsm's `ntm` and `vibing-with-ntm` skills | Use the maintained jsm workflows. Archived setup reference includes recovered installed-only model defaults. Existing project helpers require their own migration; this archive is not an active dependency. |
| `pr-closeout` | 2026-10-14 | None specified | Retired at the owner's request. |
| `p-agent-swarm-launcher` | 2026-10-14 | `flywheel-conductor-jsm` and jsm skills | Use the current conductor and native coordination workflow. |
| `p-install-agent-skill` | 2026-10-14 | Repository README install instructions | Old prompt duplicated installation behavior and obsolete bridges. |
| `caam-seat` | 2026-11-02 | Stock caam and ntm; a Linux box per account set | On macOS a Claude login can't be saved where no keychain is reachable, as in a seat: a keychain dialog appears and nothing is saved to a file. Its ntm template wrapper blocked ntm's conversation resume, and it duplicated caam #130. See `RETIRED.md` for the alternatives. |

| `prompts/p-plan-to-beads` | 2026-09-28 | `skills/beads-workflow` (`/beads-workflow`) | Plans are encoded with the beads-workflow skill, which carries the dependency, self-containment, and polish rules; the prompt was never the path actually run. |

Renames: `goal-plan` → `write-goal`; `engineering-review` → `codebase-benchmark`;
`p-pre-mortem` → `premortem-general`; `p-premortem-planner` → `premortem-spec`;
`p-agent-5-hour-trigger` → `setup-agent-rate-window-ticks`.
On 2026-11-25 the `p-` prefix was removed from all 20 prompt skills
(`p-<name>` → `<name>`), except `p-idea-wizard` → `idea-wizard-simple`, which
avoids a clash with jsm's `idea-wizard`.
These remain active under their new names. The benchmark skill explains how to
migrate its profile without losing review history.

The root `prompts/` directory was retired on 2026-11-16. All 18 active prompts
moved into native packages under `skills/`; their names and bodies were preserved.
See [migrations.json](../migrations.json) for every replacement. Git retains the
original files. No second active command collection is maintained.
