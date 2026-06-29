#!/usr/bin/env bash
# Agent Mail file-reservation (lease) guard — portable, repo-agnostic.
# Chained from an existing husky pre-commit hook by flywheel-link.sh `setup` so it
# coexists with the repo's own checks (see references/setup.md "Guards + husky").
# Blocks a commit that touches files another agent currently has reserved in Agent Mail.
#   AGENT_MAIL_BYPASS=1      skip entirely
#   AGENT_MAIL_GUARD_MODE=warn   advisory only (default: block)
set -euo pipefail

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

if truthy "${AGENT_MAIL_BYPASS:-0}"; then
  echo "[file-reservation-guard] bypassed via AGENT_MAIL_BYPASS=1" >&2
  exit 0
fi

repo_root=$(git rev-parse --show-toplevel)
git_dir=$(git rev-parse --git-dir)

if [ -f "$git_dir/MERGE_HEAD" ] || [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
  exit 0
fi

agent_mail_root="${MCP_AGENT_MAIL_ROOT:-$HOME/.local/share/mcp_agent_mail}"
agent_mail_python="${MCP_AGENT_MAIL_PYTHON:-$agent_mail_root/.venv/bin/python}"

if [ ! -x "$agent_mail_python" ]; then
  echo "[file-reservation-guard] missing Agent Mail Python at $agent_mail_python" >&2
  echo "[file-reservation-guard] set MCP_AGENT_MAIL_PYTHON or install Agent Mail before committing" >&2
  exit 1
fi

agent_name="${AGENT_NAME:-${USER:-local}-precommit}"
mode="${AGENT_MAIL_GUARD_MODE:-block}"
advisory_args=()

case "$mode" in
  warn|advisory|adv) advisory_args=(--advisory) ;;
  block|"") ;;
  *)
    echo "[file-reservation-guard] unknown AGENT_MAIL_GUARD_MODE='$mode'; expected block or warn" >&2
    exit 1
    ;;
esac

git diff --cached --name-status -M -z --diff-filter=ACMRDTU |
  "$agent_mail_python" -c '
import sys

parts = [part for part in sys.stdin.buffer.read().split(b"\0") if part]
paths: list[bytes] = []
i = 0
while i < len(parts):
    status = parts[i].decode("utf-8", "ignore")
    i += 1
    if status.startswith(("R", "C")) and i + 1 < len(parts):
        old_path = parts[i]
        new_path = parts[i + 1]
        i += 2
        paths.extend([old_path, new_path])
    elif i < len(parts):
        paths.append(parts[i])
        i += 1

seen: set[bytes] = set()
for path in paths:
    if path in seen:
        continue
    seen.add(path)
    sys.stdout.buffer.write(path + b"\0")
' |
  AGENT_NAME="$agent_name" "$agent_mail_python" -m mcp_agent_mail.cli guard check \
    --stdin-nul \
    --repo "$repo_root" \
    "${advisory_args[@]}"
