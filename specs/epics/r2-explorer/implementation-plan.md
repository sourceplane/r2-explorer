# r2-explorer — implementation plan

## RX0 — the spec (RX-1)

**Done when**
- the five documents and `epic.yaml` are on `main`, with `tasks/RX-1..RX-5.TaskContract.yaml`
- the repository's intent (`intent.yaml`, workspace `ws_CHANGE_ME` until it is linked), `ci.yml` (the plan job a green no-op until then), the workspace files and the shared tooling (`tooling/{eslint,tsconfig,wire}`) are on `main`

## RX1 — the file manager on Workers (RX-2)

**Done when**
- `apps/web` is upstream's template — R2-Explorer 1.1.10 and its dashboard, upstream's asset settings — plus `src/config.ts`, `/api/health`, `SITE_NAME`, the dashboard's build and the wrangler template with its committed fixture render
- `pnpm install && pnpm run wire:fixture && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally; `tests/web` drives the real R2-Explorer over an in-memory bucket, read-only and signed in
- `wrangler deploy --dry-run` lists `env.bucket` and `env.ASSETS`
- `wrangler dev` serves the dashboard under the product's name over a local bucket: read-only with no `.dev.vars`, and with both keys in it, every `/api` route behind HTTP Basic authentication and a file uploaded, read back and deleted
- the deploy hands the optional sign-in to the Worker as Worker secrets (`tooling/wire/worker-secrets.mjs`), the build running without it

## RX2 — the R2 bucket from Terraform (RX-3)

**Done when**
- `terraform validate` passes on `infra/terraform/cloudflare-r2`, and `r2_bucket_name` is the key the template's token names
- the root publishes `WIRING_CLOUDFLARE_R2` to stage and prod; `web` declares its edge on it, enforced on main and advisory on a pull request

## RX3 — ready to instantiate (RX-4)

**Done when**
- the README quick start works from a fresh clone: install, dev, test, preview, sign in, deploy by hand
- the status file lists every PR and every departure from upstream

## RX4 — a baseline (RX-5)

The repository becomes an Orun baseline on the Cirrus conventions, held to
the starter standard and built the way turso-starter builds a product — in
ONE landing:

- `blueprint.yaml` (the card: `requires [github, cloudflare]`, the three
  brokered secrets as a preview, the programme `01-product`, `02-docs`) and
  `repo-blueprint.yaml` (every module placed by `01-product` and landed as
  one pull request; `02-docs` hook-only);
- `web`'s edge on `cloudflare-r2` `mode: enforced` on a push to main,
  advisory on a pull request, so one convergence applies the bucket and then
  deploys the explorer per environment;
- `.baseline/`, the rename engine (`SITE_NAME`, the Worker and bucket names,
  the sign-in's secret refs — and, because the slug is the package's name,
  every place the tree names the `r2-explorer` package or Cloudflare's
  template protected), the bootstrap helpers, the deployment record,
  `ai/context/`, the generated component docs, `testing/` and the
  `baseline.yml` / `tag.yml` lanes.

**Done when**
- orun reads the build document at the bootstrap floor and the lane pin, the
  card agrees with it, and `orun catalog validate` reports no errors
- the product's own `orun plan --trigger github-push-main` applies
  `cloudflare-r2` before `web`, enforced; a pull request's plan holds the
  edge advisory
- a product built offline still pins, imports and copies the `r2-explorer`
  package under its own name
- the e2e tier builds in the job tree orun stages with a sign-in planted in
  the build's environment (and finds it in nothing the build wrote),
  dry-deploys both bindings, and serves the built Worker over a local
  bucket — the deploy's own smoke, the dashboard under the product's name,
  read-only; then signed in, every `/api` route behind the sign-in and a
  file uploaded, listed, read back and deleted
- tagged `baseline-v1` through `tag.yml`

## Sequencing note

RX1's component already names the R2 root's wiring secret; RX2 makes the
name true. Applying RX2 needs a workspace with a Cloudflare connection (the
`r2-data` token scope) whose account has R2 enabled (risk RX-I).
