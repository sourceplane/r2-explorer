# apps/web — the explorer on Workers

[R2-Explorer](https://www.npmjs.com/package/r2-explorer), a Google
Drive-style interface over an R2 bucket, from Cloudflare's
[R2 Explorer template](https://github.com/cloudflare/templates/tree/main/r2-explorer-template)
(MIT), running as one Cloudflare Worker with Static Assets, the bucket bound
as `bucket`:

- `src/index.ts` — the Worker: `/api/health`, then everything else to
  R2-Explorer's app (its API under `/api`, its dashboard from `ASSETS`). The
  app is handed only its two bindings, so no secret is ever offered to it as
  a bucket
- `src/config.ts` — what R2-Explorer is told, from the Worker's secrets:
  **read-only** with no sign-in stored, as upstream ships it; HTTP Basic
  authentication and changes allowed with BOTH `BASIC_AUTH_USERNAME` and
  `BASIC_AUTH_PASSWORD`. Cloudflare Access and Email Routing are left out
- `src/health.ts` — `GET /api/health`: lists one key of the bucket and
  answers `{ ok, name, bucket, mode }`, or `503` when the binding is missing
  or the list fails. It is the deploy's smoke check, the one route only this
  Worker, bound to its bucket, can answer
- `src/site.ts` — the explorer's name, the dashboard's `<title>`
- `scripts/build-dashboard.mjs` — copies the package's prebuilt dashboard
  into `dist/dashboard` (the Worker's Static Assets) and sets its `<title>`
  (`scripts/dashboard-title.mjs`)

```bash
pnpm dev        # the dashboard copied, then wrangler dev on http://localhost:8787 with a local R2 bucket
pnpm build      # the dashboard → dist/dashboard
pnpm preview    # the same, over the built assets
```

Sign in locally by copying `.dev.vars.example` to `.dev.vars` and setting
both keys. On a deployed environment they are the Orun secrets of the same
names; the deploy pushes them to the Worker as Worker secrets
(`tooling/wire/worker-secrets.mjs`), and the build itself never sees them.

The bucket needs no key: the Worker binds it. Its name is not hand-written
either. `wrangler.template.jsonc` names it as a wiring token;
`wrangler.jsonc` is that template rendered from `wiring.fixture.json`
(placeholder names, for local work and verification), and every deploy
renders it again from the name the `cloudflare-r2` Terraform root published
for the environment (`component.yaml`'s `buildCommand`).

⚠️ Read-only is not private: with no sign-in stored, anyone with the URL can
browse and download everything in the bucket, as with upstream's default.
Store the sign-in before putting anything private in it.
