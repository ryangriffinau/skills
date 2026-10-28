# Why Claude seats need the Keychain step on macOS

Reported upstream: [caam #130](https://github.com/Dicklesworthstone/coding_agent_account_manager/issues/130). Verified on 2026-10-28 with caam 0.1.23, Claude Code 2.1.312, and macOS 26.6.2. The caam code path is unchanged on `main` after v0.1.24.

## What happens

1. Claude Code on macOS keeps its OAuth token in the login Keychain, as a generic password with service `Claude Code-credentials`. It reads the Keychain first and falls back to `~/.claude/.credentials.json` only when the Keychain is unreachable. caam documents this in `internal/keychain/keychain.go`.
2. `security` finds the login Keychain through `$HOME/Library/Keychains/login.keychain-db`.
3. caam's shallow profiles symlink every top-level entry of the real HOME except caam's own data and the provider roots. That includes `Library`. So `$SHALLOW_HOME/Library/Keychains` is the real Keychains directory.
4. Result: a Claude shallow profile reads the active account's token from the real Keychain and ignores its own credentials file.

caam's fix for #98 assumed step 3 did not happen: "a shallow profile's HOME has no login keychain and Claude Code falls back to that lane's own `.credentials.json`".

## Evidence

| Probe | Library symlinked (caam default) | Library real, Keychains withheld |
|---|---|---|
| `HOME=<seat> security list-keychains` | real `login.keychain-db` + System | System only |
| `HOME=<seat> security login-keychain` | found | "could not be found" |
| `HOME=<seat> security default-keychain` | real login keychain | "A default keychain could not be found" |
| `claude auth status`, empty seat | `loggedIn: true`, `subscriptionType: max` (the active account) | `loggedIn: false` |
| `claude auth status`, seat file holds a test credential with `subscriptionType: pro` | (not run: it risks writing to the real item) | `loggedIn: true`, `subscriptionType: pro` (the seat's file) |

`gh auth status` and `git ls-remote` over HTTPS through `gh auth git-credential` both worked inside a seat with Keychains withheld.

## Options considered

1. **Withhold `Library/Keychains`** (what caam-seat does). Keeps the seat's credentials in the file caam already manages, which is what caam's design expects. The cost is that a tool keeping its secret only in the login Keychain can't see it inside the seat. git's `osxkeychain` helper is one example.
2. **Pin `CLAUDE_CONFIG_DIR` to the seat's `.claude`.** Claude Code then uses a Keychain item named after the config dir, so seats stop sharing the item. It works: an empty seat showed `loggedIn: false`. The costs:
   - caam's `shallow-spawn` scrubs `CLAUDE_CONFIG_DIR`, so it has to be set inside the spawned command.
   - Claude Code then reads `$CLAUDE_CONFIG_DIR/.claude.json` instead of `$HOME/.claude.json`, which bypasses caam's config sync unless that file is symlinked.
   - The token lives in a Keychain item caam does not bridge, so caam cannot see or check the seat's login.

Option 1 was chosen because it makes caam's own assumption true instead of adding a parallel mechanism.

## How caam-seat applies it

- `isolate_seat` takes a per-seat lock. If `Library` is a symlink, it builds a real directory that links every child of the real `~/Library` (from the seat's `.caam-shallow.json` `real_home`) except `Keychains`, removes the symlink, and moves the directory into place. On later runs it links any new children and removes a `Keychains` link if one appears.
- After every repair it runs `HOME=<seat> security login-keychain`. If that succeeds, the launch is refused with exit 4.
- `launch` and `run` repair before every start. ntm can start several panes on one seat at once, and the lock covers that case; the tests run four concurrent launches.
- Codex seats are left alone. caam forces `cli_auth_credentials_store = "file"` and pins `CODEX_HOME`.
