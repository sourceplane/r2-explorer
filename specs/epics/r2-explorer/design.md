# r2-explorer — design

## 1. What the template is

Cloudflare's [`r2-explorer-template`](https://github.com/cloudflare/templates/tree/main/r2-explorer-template)
is a configuration of the npm package [R2-Explorer](https://www.npmjs.com/package/r2-explorer)
1.1.10, nothing more. Its `src/index.ts` is one call —
`export default R2Explorer({ readonly: true })`, with Cloudflare Access
(`cfAccessTeamName`) commented out — and its `wrangler.json` serves the
package's prebuilt dashboard (`node_modules/r2-explorer/dashboard`, a
single-page app) as Static Assets with `html_handling: auto-trailing-slash`
and `not_found_handling: single-page-application`, and binds one bucket,
`r2-explorer-bucket`, as `bucket`. The README creates the bucket by hand
(`npx wrangler r2 bucket create r2-explorer-bucket`) and deploys with
`npx wrangler deploy`; to allow changes, its owner edits `readonly` and is
told to "setup security first".

R2-Explorer itself is a Hono app (chanfana's OpenAPI router) under `/api`:
the server's config and the buckets it can see (`/api/server/config`),
listing, reading, uploading (single and multipart), folders, moving,
renaming, metadata and deleting (`/api/buckets/:bucket/…`), and an `email`
handler that stores mail delivered by Email Routing. Its security options
are `readonly`, `basicAuth` (one or more username/password pairs, checked
on every `/api` route) and `cfAccessTeamName`.

## 2. The mapping (upstream → here)

| The template | Here |
|---|---|
| `R2Explorer({ readonly: true })` as the Worker's default export | `src/index.ts`: R2-Explorer's app built from `configFor(env)` (`src/config.ts`), handed only the `ASSETS` and `bucket` bindings; `/api/health` answered first |
| `readonly` edited by hand | read-only with no sign-in stored; `readonly: false` and `basicAuth` with both `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` (§3) |
| `cfAccessTeamName` (commented out) | left out (§6) |
| The `email` handler (Email Routing) | left out: `emailRouting: false`, and the Worker exports `fetch` only (§6) |
| Assets from `node_modules/r2-explorer/dashboard` | `scripts/build-dashboard.mjs` copies the directory into `dist/dashboard` and sets its `<title>` to `SITE_NAME` (`src/site.ts`); the same asset settings |
| `"bucket_name": "r2-explorer-bucket"` (and its `preview_bucket_name`) | `@@wiring(cloudflare-r2/__ENV__:r2_bucket_name)@@`, rendered per environment (§4); `wrangler dev` uses a local bucket |
| `wrangler r2 bucket create` | `infra/terraform/cloudflare-r2`, one private bucket per environment |
| `wrangler deploy` | Orun: `apps/web/component.yaml` renders the config for `$ORUN_ENVIRONMENT`, copies the dashboard, pushes the sign-in, and deploys `r2-explorer-web-{stage,prod}` on merge to `main`, after the bucket's apply |
| npm, `package-lock.json` (R2-Explorer 1.1.10, `hono` 4.13.8) | pnpm, both pinned exactly — `hono` is the peer R2-Explorer's own dependencies (`chanfana`, `@hono/cloudflare-access`) need, at the version upstream's lockfile resolved |
| `worker-configuration.d.ts` (`wrangler types`) | `cloudflare-env.d.ts` and `@cloudflare/workers-types` |

Alternative rejected: rebuilding the dashboard from R2-Explorer's sources (a
Quasar app). The package ships it built, the template serves it as shipped,
and a rebuild would pin a second toolchain for no change in what a visitor
sees. Only its `<title>` is set, so the browser tab carries the product's
name.

## 3. The configuration, and the sign-in

`configFor(env)` reads two optional values:

```
BASIC_AUTH_USERNAME (trimmed) and BASIC_AUTH_PASSWORD both non-empty
  → { readonly: false, emailRouting: false, basicAuth: { username, password } }
otherwise
  → { readonly: true,  emailRouting: false }               (upstream's default)
```

One of the two alone is not a sign-in: the explorer stays read-only, and
`/api/health` reports `"mode": "read-only"`. The app is built once per
configuration and reused across requests.

On a deployed environment the two values are Orun secrets of the product
(`optionalSecretEnv` in `apps/web/component.yaml`, `secret://<repo>/<repo>/<env>/BASIC_AUTH_*`),
set by the owner after the build — never minted, never part of the build's
consent. The Worker reads them at request time, so the deploy lane hands
them to the Worker as **Worker secrets**: the build runs with both unset
(`env -u`), then `tooling/wire/worker-secrets.mjs` pipes the ones present to
`wrangler secret bulk --name <repo>-web-<env>` over stdin. No bundle, asset,
config file or log holds them. Locally they are `apps/web/.dev.vars`.

R2-Explorer is handed `{ ASSETS, bucket }`, not the Worker's env: its routes
address a binding by the name in the URL (`/api/buckets/<binding>/…`) and
its config lists every binding with `get` and `put` methods, so with two
bindings nothing else — the sign-in included — is in any route's reach.

## 4. The bindings and the wiring flow

| Binding | Kind | From |
|---|---|---|
| `bucket` | R2 bucket | `r2_bucket_name` in the `cloudflare-r2` root's wiring document |
| `ASSETS` | Static Assets | `dist/dashboard`, the build's copy of the dashboard |

The binding's name is upstream's: R2-Explorer shows it as the bucket's name
in the dashboard. `wrangler.template.jsonc` carries the wiring token;
`pnpm run wire:fixture` renders it from `wiring.fixture.json` into the
committed `wrangler.jsonc` (the deploy lane checks the config exists before
it builds); the stage and prod lanes render from
`WIRING_CLOUDFLARE_R2_<ENV>`, and dev, which no root applies to, from the
fixture. The R2 root applies with its own `r2-data` key
(`CLOUDFLARE_R2_TOKEN`), because the `workers-deploy` token cannot touch R2.

`/api/health` (`src/health.ts`) lists one key of `bucket` and answers
`{ ok: true, name, bucket: "bucket", mode }`, or `503 { ok: false, error }`
when the binding is missing or the list throws, never cached. It is the
deploy's smoke and the deployment record's probe because it is the one
read-only route only this Worker, bound to its bucket, can answer: the
dashboard alone answers from Static Assets whether a bucket exists or not.

## 5. The repository

```
apps/web                          the template + the Workers build
  src/index.ts                    the Worker: /api/health, then R2-Explorer
  src/config.ts                   the configuration from the sign-in (§3)
  src/health.ts                   GET /api/health (§4)
  src/site.ts                     SITE_NAME, the dashboard's title (the rebrand's seam)
  scripts/build-dashboard.mjs     the dashboard → dist/dashboard, titled
  scripts/dashboard-title.mjs     reading SITE_NAME, setting <title>
  wrangler.template.jsonc         the config's source (§4); wrangler.jsonc its fixture render
  component.yaml                  the deploy contract
  .dev.vars.example               the local sign-in
  LICENSE                         upstream's (Cloudflare, MIT)
tests/web                         vitest: config, health, the Worker through the real R2-Explorer, the title
infra/terraform/cloudflare-r2     one private bucket per environment; publishes WIRING_CLOUDFLARE_R2
tooling/wire                      the wrangler renderer; worker-secrets.mjs
```

The bucket before the Worker: `apps/web` declares `dependsOn:
cloudflare-r2`, `mode: enforced` on a push to main and advisory on a pull
request, so one landing applies the bucket and then deploys the Worker that
binds it.

## 6. Out of scope

- **Cloudflare Access** (`cfAccessTeamName`). An Access application is a
  Zero Trust resource no Orun composition provisions, and the brokered
  tokens carry no Access permission. HTTP Basic authentication is
  R2-Explorer's other supported guard, and the one a product can switch on
  with two secrets. An owner who wants Access creates the application by
  hand and passes its team name in `src/config.ts`.
- **Email Routing** into the bucket. It needs a zone with Email Routing
  enabled and a rule that routes to the Worker — a zone resource no
  composition provisions and the brokered tokens do not reach. The Worker
  exports no `email` handler, and R2-Explorer is told `emailRouting: false`.
- **A custom domain.** The explorer goes live on workers.dev; attaching a
  domain is the owner's step (the product's README, "Custom domain").
- **More than one bucket** or **more than one user.** Both are R2-Explorer
  features (more bindings; more `basicAuth` pairs) an owner can add in
  `wrangler.template.jsonc` and `src/config.ts`; the baseline ships one of
  each.
