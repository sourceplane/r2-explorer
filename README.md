# r2-explorer

Cloudflare's [R2 Explorer template](https://github.com/cloudflare/templates/tree/main/r2-explorer-template)
— [R2-Explorer](https://www.npmjs.com/package/r2-explorer), a Google
Drive-style interface over an R2 bucket: folders, drag-and-drop and
multipart uploads, in-browser previews of images, PDFs, text, Markdown and
CSV, in-place editing, metadata — running on **Cloudflare Workers + Static
Assets**, with the bucket provisioned by Terraform through
[Orun](https://github.com/sourceplane/orun) — and, at its last milestone
(RX4), packaged as an **Orun baseline**: one command taking a new product
from nothing to live on stage and prod, in its own repository, under its own
name, in ONE landing.

The explorer and its dashboard are upstream's, unchanged: the Worker mounts
R2-Explorer's app, and the build copies its prebuilt dashboard into the
Worker's Static Assets, its `<title>` set to the product's name. It ships
**read-only**, as upstream does, until its owner stores a sign-in; then it
asks for HTTP Basic authentication and allows changes. See
[`specs/epics/r2-explorer`](specs/epics/r2-explorer/README.md) for the
design, the milestones and the as-built status.

## What is here

| Surface | Where |
|---|---|
| The Worker: R2-Explorer, configured per environment, and its health route | `apps/web/src/index.ts`, `apps/web/src/config.ts`, `apps/web/src/health.ts` |
| The site's name (the dashboard's `<title>`) | `apps/web/src/site.ts` |
| The dashboard, copied from the package into Static Assets | `apps/web/scripts/build-dashboard.mjs`, `apps/web/scripts/dashboard-title.mjs` |
| Workers bindings and deploy contract | `apps/web/wrangler.template.jsonc` + `wiring.fixture.json` (→ the committed `wrangler.jsonc`), `component.yaml` |
| The sign-in's path to the Worker (Worker secrets) | `tooling/wire/worker-secrets.mjs` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
| The wrangler renderer | `tooling/wire` |
| Tests | `tests/web` (vitest: the configuration, the health route, the Worker through the real R2-Explorer over an in-memory bucket, the dashboard's title) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/web/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # the dashboard → apps/web/dist/dashboard
```

```bash
pnpm --filter @app/web dev        # wrangler dev: the explorer on http://localhost:8787, a local R2 bucket
cp apps/web/.dev.vars.example apps/web/.dev.vars   # set both keys to sign in and allow changes
```

## Signing in

The explorer is **read-only until you set a sign-in**, as upstream ships it:
anyone with the URL can browse the bucket and download what is in it, and
no one can change it. Store `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`
for an environment — Orun secrets, `orun secrets set <KEY> --env <env>` —
and redeploy it: the deploy pushes both to the Worker as Worker secrets, and
from then on every `/api` route asks for HTTP Basic authentication and the
signed-in user may upload, move, rename and delete. One of the two alone
leaves it read-only. Locally, the same two keys go in `apps/web/.dev.vars`.

## Deploying

A merge to `main` applies the R2 bucket on stage and prod and then deploys
`r2-explorer-web-{stage,prod}` bound to it, once `intent.yaml` names the
product's Orun workspace (it names the placeholder `ws_CHANGE_ME` until it
is linked, and CI plans nothing). By hand: Run workflow on `main` (`ci.yml`)
with the environment, and optionally the components, to deploy.

## How it maps to Cloudflare's template

| The template | Here |
|---|---|
| `src/index.ts`: `R2-Explorer({ readonly: true })` | The same app, its configuration read from the Worker's secrets: read-only with none, HTTP Basic sign-in and changes allowed with both (`apps/web/src/config.ts`) |
| `readonly: true` edited by hand to allow uploads | Store `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` and redeploy |
| Cloudflare Access (`cfAccessTeamName`) | Left out: an Access application is a Zero Trust resource no Orun composition provisions — Basic auth instead |
| Email Routing into the bucket (the `email` handler) | Left out: no composition for Email Routing; the Worker exports `fetch` only |
| Assets served from `node_modules/r2-explorer/dashboard` | Copied into `dist/dashboard` by the build, its `<title>` the product's name; the same `html_handling` and single-page-application fallback |
| A bucket created with `wrangler r2 bucket create` | `infra/terraform/cloudflare-r2`, applied by Orun before the Worker deploys, one bucket per environment |
| `npx wrangler deploy` | Orun applies the bucket and deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |
| "Deploy to Cloudflare" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |
| npm, R2-Explorer 1.1.10, `hono` from its lockfile | pnpm, both pinned exactly (R2-Explorer 1.1.10, `hono` 4.13.8) |

## How the bucket name reaches the Worker

```
infra/terraform/cloudflare-r2 ──apply──► orun secret WIRING_CLOUDFLARE_R2 (stage, prod)
   (CLOUDFLARE_R2_TOKEN, r2-data)              │   (each deploy resolves it as it starts;
                                               │    a missing one fails the lane)
                                               ▼
apps/web  dependsOn cloudflare-r2 (enforced on main) · secretEnv WIRING_CLOUDFLARE_R2_<ENV>
          optionalSecretEnv BASIC_AUTH_USERNAME, BASIC_AUTH_PASSWORD
  build:  tooling/wire/live.mjs → wrangler.jsonc with the environment's bucket name
          (dev, verify-only, renders the fixture) → the dashboard copied into place
          → tooling/wire/worker-secrets.mjs: the sign-in, when stored, to the Worker
  deploy: CLOUDFLARE_API_TOKEN (workers-deploy) — the running Worker holds no storage key
```

`wrangler.jsonc` is committed as the fixture render of
`wrangler.template.jsonc`, because the deploy lane's `verify-app-structure`
step checks the config exists before it builds; `testing/e2e.test.sh` fails
if the two disagree.

## CI

| Workflow | What it runs |
|---|---|
| `ci.yml` | the Orun pipeline: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the R2 root planned for stage and prod, the dashboard built and the Worker dry-deployed per environment, the tests run); a merge applies the R2 bucket, then deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them |

## Credits

R2-Explorer is © 2023-2025 Gabriel Massadas, MIT
([npm](https://www.npmjs.com/package/r2-explorer), installed as a
dependency, its LICENSE with it). The template this port starts from is
Cloudflare's, MIT (© 2018 Cloudflare, Inc.; kept as `apps/web/LICENSE`).
