# r2-explorer — operating contract (for humans and agents)

This is the standing guide to how this explorer is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the explorer without any
other source.

## What this system is

A file manager for an R2 bucket on Cloudflare alone —
[R2-Explorer](https://www.npmjs.com/package/r2-explorer), from Cloudflare's
[R2 Explorer template](https://github.com/cloudflare/templates/tree/main/r2-explorer-template)
— expressed as an Orun component-native desired-state repo.

- **`infra/terraform/cloudflare-r2`** — one private R2 bucket per deployed
  environment (`stage`, `prod`), applied by Terraform. After each apply it
  publishes a wiring document — `{r2_bucket_name}` — as the Orun secret
  `WIRING_CLOUDFLARE_R2` on that environment.
- **`apps/web`** — the explorer: one Worker with Static Assets. The Worker
  answers `/api/health` itself and hands everything else to R2-Explorer's
  app — its API under `/api`, reaching the bucket through the `bucket` R2
  binding, and its prebuilt dashboard, copied from the package into the
  Worker's Static Assets by the build, its `<title>` the explorer's name
  (`apps/web/src/site.ts`).
- **`tests/web`** — the configuration, the health route and the Worker
  through the real R2-Explorer over an in-memory bucket, read-only and
  signed in (vitest). Its `dev` lane installs it and checks its structure;
  the tests themselves are `pnpm test`, run before a push.
- **`tooling/*`** — shared TypeScript and ESLint configuration, the wrangler
  renderer that turns `wrangler.template.jsonc` plus a wiring document into
  `wrangler.jsonc`, and the step that hands the sign-in to the Worker as
  Worker secrets.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — its lanes build and dry-run the deploy, nothing
deploys, and no bucket exists for it (its build renders the committed
fixture).

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. **The bucket before the Worker.** `cloudflare-r2` applies for the
   environment and publishes `WIRING_CLOUDFLARE_R2`. `apps/web` declares an
   enforced `dependsOn` on it for pushes to `main`, so its deploy starts only
   after that apply — and a job resolves its secrets when it starts, so the
   document is there.
4. `apps/web` renders `wrangler.jsonc` from that document (the real bucket
   name), copies the dashboard into place, and — when the environment holds
   `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` — pushes them to
   `r2-explorer-web-<env>` as Worker secrets. `wrangler deploy` ships the
   Worker, and a smoke test requires `/api/health` to answer `"ok":true` —
   the Worker listed its bucket through the binding — and `/` to serve the
   dashboard. The smoke writes nothing.
5. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
6. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing applies or deploys: the R2 root plans, the
explorer builds and dry-deploys, and the edges in step 3 are advisory.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "explorer
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/web`.
- `wrangler.jsonc` is generated. Edit `wrangler.template.jsonc`, run
  `pnpm run wire:fixture` and commit both; the deploy renders its own
  config from the template, so a stale committed render misleads local work.
- R2 must be enabled on the Cloudflare account (dashboard → R2, once per
  account). Without it the R2 root's apply fails and the Worker, which waits
  on it, does not deploy.

## Who can do what

| Stored in the environment | The explorer |
|---|---|
| neither `BASIC_AUTH_USERNAME` nor `BASIC_AUTH_PASSWORD` (as built) | **read-only and public**: anyone with the URL can browse, preview and download everything in the bucket; every change is refused (`401`, `ReadOnly`) |
| one of the two | the same — one is not a sign-in |
| both | every `/api` route asks for HTTP Basic authentication; the signed-in user may upload, create folders, move, rename, edit metadata and delete |

`/api/health` answers without a sign-in either way; it says which mode the
Worker is in and that it can reach its bucket, and nothing about what the
bucket holds. Put nothing private in the bucket until the sign-in is stored.

## Secrets model

- **Brokered provider secrets**, minted per run from the workspace's
  Cloudflare connection — no long-lived values at rest, nothing to rotate by
  hand:
  - `CLOUDFLARE_API_TOKEN` — the `workers-deploy` scope (Workers Scripts and
    KV Storage write). The Worker's deploy, and the Worker secrets it
    pushes, use it; it cannot touch R2.
  - `CLOUDFLARE_R2_TOKEN` — the `r2-data` scope (Workers R2 Storage Write).
    The R2 root applies with it, bound there as `CLOUDFLARE_API_TOKEN`.
  - `CLOUDFLARE_ACCOUNT_ID` — a connection fact both bind.
- **The sign-in**: `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`,
  optional Orun secrets per environment (`optionalSecretEnv` in
  `apps/web/component.yaml`), set by the owner. The deploy pushes them to
  the Worker as Worker secrets (`tooling/wire/worker-secrets.mjs`, `wrangler
  secret bulk`); the build itself runs with both unset, so neither reaches
  a bundle, an asset or a log.
- **Wiring**: `WIRING_CLOUDFLARE_R2` on `stage` and `prod`, written by the
  R2 root's apply (lease-published), read by the Worker's build as
  `WIRING_CLOUDFLARE_R2_<ENV>`. It holds the bucket name, not a credential.
- **The running Worker holds no storage credential.** It reaches the bucket
  through its `bucket` binding.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.

## Verifying the system

```bash
# the explorer on each environment (also recorded, probed, in deployment.md)
curl -s https://r2-explorer-web-stage.your-workers-subdomain.workers.dev/api/health
curl -s -o /dev/null -w '%{http_code}\n' https://r2-explorer-web-prod.your-workers-subdomain.workers.dev/

# what R2-Explorer was told: readonly true, or an auth block once signed in
curl -s https://r2-explorer-web-stage.your-workers-subdomain.workers.dev/api/server/config

# signed in (both keys stored): the bucket's top level
curl -s -u "$BASIC_AUTH_USERNAME:$BASIC_AUTH_PASSWORD" \
  "https://r2-explorer-web-stage.your-workers-subdomain.workers.dev/api/buckets/bucket?limit=100"

# the wiring the deploys read, and workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| allow changes (sign in) | `orun secrets set BASIC_AUTH_USERNAME --env <env>` and `orun secrets set BASIC_AUTH_PASSWORD --env <env>` (each prompts for its value), then deploy by hand (below) — the build pushes both to the Worker |
| rotate the sign-in | set new values and deploy by hand; the push replaces the Worker's secrets |
| go back to read-only | delete both Orun secrets and the Worker's (`wrangler secret delete BASIC_AUTH_USERNAME --name r2-explorer-web-<env>`, the same for the password), then deploy by hand |
| rename the explorer | `SITE_NAME` in `apps/web/src/site.ts`, merge |
| upgrade R2-Explorer | bump the exact pin in `apps/web/package.json` (and `hono` to the version its lockfile pins), `pnpm install`, `pnpm test`, merge |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| list or delete stored files outside the explorer | `wrangler r2 object …` on the bucket named in the environment's `WIRING_CLOUDFLARE_R2` (`--remote`), or the dashboard's R2 page |
| add a binding (D1, KV, another bucket) | a Terraform root under `infra/terraform/` that publishes `WIRING_<ROOT>`, a token in `wrangler.template.jsonc`, its fixture entry, the root in the build's `--components`, the `WIRING_<ROOT>_<ENV>` secretEnv and an enforced `dependsOn` on it in `apps/web/component.yaml`. A second bucket binding is a second bucket in the dashboard: `src/index.ts` passes R2-Explorer only the bindings it names |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"), then replace the placeholder `r2-explorer.example.com` in `intent.yaml`'s `BASE_DOMAIN` with it |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Cloudflare Access (upstream's other way in, `cfAccessTeamName`) and Email
Routing into the bucket are left out: neither has an Orun composition, and
each is a Zero Trust or zone resource the brokered tokens do not reach. To
add Access, create the Access application for the Worker's hostname by hand
and pass its team name in `apps/web/src/config.ts`. Structural changes
follow the same contract that deployed the explorer: add a component under
`apps/`, `infra/` or `packages/` with a `component.yaml`, land it as a pull
request, and the convergence run applies it.
