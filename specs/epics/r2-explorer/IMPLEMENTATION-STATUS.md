# r2-explorer (RX) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template
([cloudflare/templates `r2-explorer-template`](https://github.com/cloudflare/templates/tree/main/r2-explorer-template),
at `7ae5750`, MIT).

| Milestone | State | PR |
|---|---|---|
| RX0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/r2-explorer/pull/1) (RX-1) |
| RX1 — the file manager on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/r2-explorer/pull/2) (RX-2) |
| RX2 — the R2 bucket from Terraform | ✅ Shipped (validated; apply gated on a linked workspace) | [#3](https://github.com/sourceplane/r2-explorer/pull/3) (RX-3) |
| RX3 — ready to instantiate | ✅ Shipped | [#4](https://github.com/sourceplane/r2-explorer/pull/4) (RX-4) |
| RX4 — a baseline | Planned | — |

## Departures from the upstream template

### Where it lives

Upstream's template is `apps/web` (`@app/web`) in the monorepo, with its
`LICENSE` beside it (`apps/web/LICENSE`). Its `src/index.ts` becomes three
files (`index.ts`, `config.ts`, `health.ts`) plus `site.ts`; its
`wrangler.json` becomes `wrangler.template.jsonc`, rendered per environment
into `wrangler.jsonc`. Upstream's `package-lock.json`, `tsconfig.json` and
`worker-configuration.d.ts` are not carried: pnpm locks the workspace, one
`tsconfig.json` extends the monorepo's Worker config, and
`cloudflare-env.d.ts` with `@cloudflare/workers-types` declares the
bindings. R2-Explorer's own LICENSE arrives with the package.

### The configuration — read-only, or signed in

Upstream exports `R2Explorer({ readonly: true })` and tells its owner to
edit the flag. Here `configFor(env)` (`src/config.ts`) returns upstream's
`{ readonly: true }` with no sign-in, and `{ readonly: false, basicAuth: {
username, password } }` with both `BASIC_AUTH_USERNAME` (trimmed) and
`BASIC_AUTH_PASSWORD` non-empty; one alone is read-only. Every config says
`emailRouting: false`. The app is built per configuration and cached, and
is handed `{ ASSETS, bucket }` only (risk RX-H).

### The sign-in's path to the Worker

The two keys are optional Orun secrets (`optionalSecretEnv`), so a product
deploys without them. The deploy's `buildCommand` renders the config, runs
the build with both unset (`env -u BASIC_AUTH_USERNAME -u
BASIC_AUTH_PASSWORD`), then `tooling/wire/worker-secrets.mjs` pushes the
ones present to `<repo>-web-<env>` with `wrangler secret bulk` over stdin,
naming nothing when none is stored. Locally, `worker-secrets.mjs
--dev-vars` writes the same keys into `.dev.vars`.

### `/api/health`

New. Answered before R2-Explorer for `GET`/`HEAD`: it lists one key of the
bucket and answers `{ ok: true, name, bucket: "bucket", mode }` (`mode`
`read-only` or `read-write`), or `503 { ok: false, error }`; never cached,
never authenticated, naming no object. It is the component's smoke
(`"ok":true`, then `/` serving the dashboard, `id=q-app`) and the
deployment record's probe.

### The dashboard and `SITE_NAME`

Upstream serves `node_modules/r2-explorer/dashboard` in place. Here
`scripts/build-dashboard.mjs` copies it (56 files, dereferenced out of
pnpm's store) into `dist/dashboard` — the directory the composition's
`assetsDir` and the build-output check name — and sets the `<title>` of
`index.html` and `spa/index.html` from `R2-Explorer` to `SITE_NAME`
(`src/site.ts`, `My Files` in this repository), HTML-escaped. Nothing else
in the dashboard changes. The asset settings are upstream's
(`html_handling: auto-trailing-slash`, `not_found_handling:
single-page-application`).

### Left out: Cloudflare Access, Email Routing

`cfAccessTeamName` (commented out upstream) and the `email` handler are not
carried (risks RX-C, RX-D). The Worker exports `fetch` only.

### The bucket

Upstream's `r2-explorer-bucket` (and its `preview_bucket_name`) becomes one
private bucket per environment from `infra/terraform/cloudflare-r2`, its
name rendered into the binding from `WIRING_CLOUDFLARE_R2_<ENV>`;
`wrangler dev` uses a local bucket. The binding keeps upstream's name,
`bucket`, which the dashboard shows.

### Behaviour kept as upstream, recorded

- Read-only means public: no sign-in, no authentication (risk RX-A).
- A browser navigation to an `/api` path is answered by the
  single-page-application fallback, not the Worker, as upstream; the
  dashboard's own requests and `curl` reach the Worker.
- R2-Explorer's routes, its OpenAPI schema and its error shapes
  (a refused write is `401`, code 10005, "This instance is in ReadOnly
  Mode, no changes are allowed!") are the package's.

## Versions

| Package | Version | Why |
|---|---|---|
| r2-explorer | 1.1.10 | upstream's pin |
| hono | 4.13.8 | upstream's lockfile's (the peer `chanfana` and `@hono/cloudflare-access` need) |
| wrangler | ^4.151.0 | the conventions' deploy CLI; upstream pins 4.136.1 |
| compatibility_date | 2026-10-01 | the conventions'; upstream's is 2025-10-08 |

## Verified (RX1–RX3)

- `pnpm install`, `pnpm run wire:fixture`, `pnpm typecheck`, `pnpm lint`,
  `pnpm test` (`tests/web`, 19 tests: the configuration, the health route,
  the Worker through the real R2-Explorer over an in-memory bucket —
  read-only listing, writes refused, the sign-in required and accepted, a
  folder created, no secret offered as a bucket, no `email` export — and the
  dashboard's title) and `pnpm build` green.
- `wrangler deploy --dry-run`: `env.bucket (stg-r2-explorer-stage) R2
  Bucket` and `env.ASSETS Assets`.
- `wrangler dev` from a fresh tree: the dashboard under its name, its
  single-page routes and assets; `/api/health` read-only; with `.dev.vars`
  holding both keys, every `/api` route `401` without them and a file
  uploaded, read back and deleted with them.
- `terraform validate` green on `infra/terraform/cloudflare-r2`.
- Not verified: a Terraform apply and a live deploy — both need the product
  linked to an Orun workspace with a Cloudflare connection (risk RX-G).
