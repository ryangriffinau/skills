# Evidence: capture policy and the harness

Screenshots are the acceptance evidence, not decoration. Green unit tests have
repeatedly closed UI work while the surface was visibly broken.

## The capture must be of the page you asked for

This is the rule the harness exists to enforce, and it is not hypothetical. A stored
browser session whose short-lived token has expired sends the **first navigation of each
fresh context** to the login screen while later navigations succeed. The resulting
login-page images look plausible and get reasoned about as if they were the app. In one
review, three of the first ten captures were of the login page.

So every capture run does two things before an image counts:

1. **Warm up** on a known authenticated route and wait for the app's own ready signal.
2. **Assert the final URL** matches what was requested, and reject the capture if not.

`scripts/shoot.mjs` does both and exits non-zero if anything was rejected. Never reason
about an image it rejected.

## Which captures to take

- **Light mode: every surface, at every viewport.**
- **Dark mode: only where the theme can actually diverge.** If the project defines both
  modes per token and a contract test locks the bridge, that test is the mechanical
  dark-mode gate. Capture dark only when (a) a finding is itself a theme defect, or
  (b) the work changes colour tokens or a shared component's colours — and then one
  representative surface at one width suffices, because the token propagates.
  A project with no token contract gets the full dark matrix.

State the policy decision in the report's screenshot index, so a reader can see the
absence was reasoned rather than forgotten.

## Harness config

```json
{
  "baseUrl": "http://localhost:3000",
  "storageState": "/tmp/app-e2e/admin.json",
  "warmup": { "path": "/home", "waitFor": "window.Clerk?.loaded === true" },
  "viewports": [
    { "name": "desktop", "width": 1440, "height": 900 },
    { "name": "mobile",  "width": 390,  "height": 844 }
  ],
  "vars": { "findingId": "abc123" },
  "surfaces": [
    { "slug": "list",     "path": "/quality" },
    { "slug": "empty",    "path": "/quality?q=zzzznomatch" },
    { "slug": "detail",   "path": "/quality/{{findingId}}" },
    { "slug": "notfound", "path": "/quality/does-not-exist" },
    { "slug": "denied",   "path": "/quality/{{findingId}}", "expectUrl": "/forbidden" }
  ]
}
```

- `warmup.waitFor` is a predicate string evaluated in the page. Use the app's real
  readiness signal, not a timeout.
- `expectUrl` declares an intentional redirect, so permission-denied surfaces assert
  their destination instead of being rejected.
- `theme: "dark"` sets the emulated colour scheme and suffixes the filenames.
- `vars` fills `{{placeholders}}` in paths, so fixture ids stay out of the config body.

Run it from a directory where the project's own Playwright is installed — the harness
resolves `@playwright/test` from the project under review rather than vendoring one.

```bash
node scripts/shoot.mjs shots.json --out docs/design/<area>-<date>
```

## Reuse the project's own authenticated session

Prefer whatever mechanism the repo's e2e suite already uses to reach authenticated
pages: test identities, storage state, a testing-token helper. It is sanctioned, it
avoids real credentials, and it is already maintained. Do not sign in as a real user to
take a screenshot.

If the stored state is stale, refresh it through the repo's own setup step rather than
working around the symptom — a warm-up that "usually works" reintroduces the exact
failure this policy exists to prevent.
