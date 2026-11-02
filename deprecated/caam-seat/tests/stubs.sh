#!/usr/bin/env bash
# Shared test fixture: a temporary HOME with a fake macOS Library and login
# Keychain, plus stub caam / claude / codex / security / ntm / tmux binaries.
# Sourced by the *.test.sh files. Never touches the operator's real HOME.
#
# The stubs model the behaviour that matters:
#   - caam shallow-profile create symlinks Library into the seat, like caam does;
#   - security finds a login Keychain only if $HOME/Library/Keychains has one;
#   - claude reads the Keychain item first and its credentials file second,
#     like Claude Code on macOS, and writes logins to the Keychain when reachable.

set -euo pipefail

STUB_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/caam-seat-test.XXXXXX")"
trap 'rm -rf "$STUB_ROOT"' EXIT

export REAL_HOME="$STUB_ROOT/home"
export HOME="$REAL_HOME"
export CAAM_SHALLOW_HOMES_DIR="$HOME/orch-homes"
export CAAM_SEAT_PLATFORM="Darwin"
export STUB_LOG="$STUB_ROOT/calls.log"
export STUB_PROFILES="$STUB_ROOT/profiles.json"
export NTM_CONFIG="$HOME/.config/ntm/config.toml"
unset NTM_CC_SEAT NTM_COD_SEAT CLAUDE_CONFIG_DIR CODEX_HOME CAAM_SEAT_ASSUME_TTY CAAM_SEAT_PINS XDG_CONFIG_HOME

STUB_BIN="$STUB_ROOT/bin"
mkdir -p "$STUB_BIN" "$CAAM_SHALLOW_HOMES_DIR" "$HOME/.claude" "$HOME/.codex" "$HOME/.config/ntm"
mkdir -p "$HOME/Library/Keychains" "$HOME/Library/Preferences" "$HOME/Library/Application Support"
: >"$HOME/Library/Keychains/login.keychain-db"
: >"$HOME/Library/.localized"
# The active account's login, as Claude Code files it in the login Keychain.
printf '{"claudeAiOauth":{"accessToken":"tok-active","refreshToken":"ref-active","subscriptionType":"max"},"email":"ryan@example.com"}\n' \
  >"$HOME/Library/Keychains/claude-credentials.json"
printf '{}\n' >"$HOME/.claude.json"
: >"$STUB_LOG"

cat >"$STUB_PROFILES" <<'JSON'
{"profiles": [
  {"tool": "claude", "name": "ryan@example.com", "active": true, "system": false,
   "identity": {"email": "ryan@example.com", "plan_type": "max"}},
  {"tool": "claude", "name": "alt@example.com", "active": false, "system": false,
   "identity": {"email": "alt@example.com", "plan_type": "max"}},
  {"tool": "claude", "name": "work@corp.example", "active": false, "system": false,
   "identity": {"email": "work@corp.example", "plan_type": "team"}},
  {"tool": "claude", "name": "_backup_1", "active": false, "system": true,
   "identity": {"email": "alt@example.com", "plan_type": "max"}},
  {"tool": "codex", "name": "main", "active": true, "system": false,
   "identity": {"email": "ryan@example.com", "plan_type": "pro"}}
]}
JSON

cat >"$STUB_BIN/caam" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
BASE="${CAAM_SHALLOW_HOMES_DIR:-$HOME/orch-homes}"
printf 'caam %s\n' "$*" >>"$STUB_LOG"
case "${1:-}" in
  version) echo "caam 0.1.23 (stub)" ;;
  ls) cat "$STUB_PROFILES" ;;
  shallow-spawn)
    shift
    if [ "${1:-}" = "--help" ]; then echo "shallow-spawn help"; exit 0; fi
    name="$1"; shift
    home="$BASE/$name"
    if [ ! -f "$home/.caam-shallow.json" ]; then
      echo "Error: shallow profile \"$name\" does not exist" >&2
      exit 1
    fi
    provider="$(jq -r '.provider' "$home/.caam-shallow.json")"
    if [ "${1:-}" = "--print-env" ]; then printf 'HOME=%s\nSHALLOW_PROFILE=%s\n' "$home" "$name"; exit 0; fi
    [ "${1:-}" = "--" ] && shift
    unset CLAUDE_CONFIG_DIR CODEX_HOME
    export HOME="$home" SHALLOW_PROFILE="$name"
    if [ "$provider" = "codex" ]; then export CODEX_HOME="$home/.codex"; fi
    exec "$@"
    ;;
  shallow-profile)
    shift
    case "${1:-}" in
      list)
        rows=""
        for d in "$BASE"/*/; do
          [ -f "$d.caam-shallow.json" ] || continue
          n="$(basename "$d")"
          rows="$rows$(jq -nc --arg n "$n" --arg p "${d%/}" '{name: $n, path: $p}')"$'\n'
        done
        printf '%s' "$rows" | jq -s --arg b "$BASE" '{base_dir: $b, profiles: ., count: length}'
        ;;
      create)
        name="$2"; shift 2
        tool="claude"
        while [ "$#" -gt 0 ]; do
          case "$1" in --tool) tool="$2"; shift ;; esac
          shift
        done
        home="$BASE/$name"
        mkdir -p "$home"
        ln -s "$HOME/Library" "$home/Library"
        printf '{}\n' >"$home/.claude.json"
        if [ "$tool" = "claude" ]; then
          mkdir -p "$home/.claude"
          : >"$home/.claude/.credentials.json"
        else
          mkdir -p "$home/.codex"
          : >"$home/.codex/auth.json"
          printf 'cli_auth_credentials_store = "file"\n' >"$home/.codex/config.toml"
        fi
        jq -n --arg n "$name" --arg t "$tool" --arg r "$HOME" \
          '{name: $n, provider: $t, real_home: $r, version: 1}' >"$home/.caam-shallow.json"
        ;;
      *) echo "stub caam: unsupported shallow-profile $*" >&2; exit 2 ;;
    esac
    ;;
  *) echo "stub caam: unsupported $*" >&2; exit 2 ;;
esac
STUB

cat >"$STUB_BIN/security" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  login-keychain)
    if [ -e "$HOME/Library/Keychains/login.keychain-db" ]; then
      printf '    "%s/Library/Keychains/login.keychain-db"\n' "$HOME"
      exit 0
    fi
    echo "security: SecKeychainCopyLogin: The specified keychain could not be found." >&2
    exit 50
    ;;
  *) exit 1 ;;
esac
STUB

cat >"$STUB_BIN/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
item="$HOME/Library/Keychains/claude-credentials.json"
creds="$HOME/.claude/.credentials.json"
case "${1:-} ${2:-}" in
  "auth status")
    if [ -e "$HOME/Library/Keychains/login.keychain-db" ] && [ -s "$item" ]; then
      jq -c '{loggedIn: true, source: "keychain", email: .email}' "$item"
    elif [ -s "$creds" ]; then
      jq -c --slurpfile cfg "$HOME/.claude.json" '{loggedIn: true, source: "file", email: ($cfg[0].oauthAccount.emailAddress // null)}' "$creds"
    else
      echo '{"loggedIn": false}'
    fi
    ;;
  "auth login")
    shift 2
    email="${STUB_LOGIN_EMAIL:-}"
    while [ "$#" -gt 0 ]; do
      case "$1" in --email) email="${STUB_LOGIN_EMAIL:-$2}"; shift ;; esac
      shift
    done
    blob="$(jq -nc --arg e "$email" '{claudeAiOauth: {accessToken: ("tok-" + $e), refreshToken: ("ref-" + $e)}, email: $e}')"
    if [ -e "$HOME/Library/Keychains/login.keychain-db" ]; then
      printf '%s\n' "$blob" >"$item"
    else
      printf '%s\n' "$blob" >"$creds"
    fi
    jq --arg e "$email" '.oauthAccount = {emailAddress: $e}' "$HOME/.claude.json" >"$HOME/.claude.json.tmp"
    mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
    ;;
  *) printf 'claude-ran HOME=%s args=%s\n' "$HOME" "$*" ;;
esac
STUB

cat >"$STUB_BIN/codex" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  login)
    email="${STUB_CODEX_EMAIL:-codex@example.com}"
    payload="$(printf '{"email":"%s"}' "$email" | base64 | tr -d '\n=' | tr '+/' '-_')"
    jq -n --arg t "x.$payload.y" '{auth_mode: "chatgpt", tokens: {id_token: $t, refresh_token: "ref", access_token: "acc"}}' \
      >"${CODEX_HOME:-$HOME/.codex}/auth.json"
    ;;
  *) printf 'codex-ran HOME=%s CODEX_HOME=%s args=%s\n' "$HOME" "${CODEX_HOME:-}" "$*" ;;
esac
STUB

cat >"$STUB_BIN/ntm" <<'STUB'
#!/usr/bin/env bash
printf 'ntm %s\n' "$*" >>"$STUB_LOG"
if [ "${3:-}" = "config" ] && [ "${4:-}" = "validate" ]; then
  if [ -n "${STUB_NTM_REJECT_WIRED:-}" ] && grep -q 'caam-seat launch' "$2"; then
    echo '{"valid": false}'
  else
    echo '{"valid": true}'
  fi
fi
exit 0
STUB

cat >"$STUB_BIN/tmux" <<'STUB'
#!/usr/bin/env bash
printf 'tmux %s\n' "$*" >>"$STUB_LOG"
STUB

chmod +x "$STUB_BIN"/*
export PATH="$STUB_BIN:$PATH"

fail() { echo "not ok - $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3: expected [$2] in: $1"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "$3: did not expect [$2] in: $1"; }
