# 01-product — the product, built in one landing

**Places** every module: the root manifests, CI, tooling and the identity
file; `infra/terraform/cloudflare-r2` (the R2 bucket per environment);
`apps/web` (R2-Explorer on the Worker, its health route, the dashboard's
build, its wrangler template and fixture, its deploy contract); `tests/web`
(vitest). Then brands them, lands them as
ONE pull request, and watches the ONE convergence that merge triggers.

**Requires** both connections live — GitHub (the App installation on the
OWNER of the repository, the only way the platform sees its pull requests)
and Cloudflare (every deploy credential below is minted from it) — probed,
waited for up to ten minutes each, so the consent can be clicked while it
waits.

## What runs

The run's task set-up — the epic, both milestones, both tasks — runs in the
background from the start (`background: true`), so every hook up to `task`
runs beside it; `task` is the first that waits for it.

| hook | what it does |
|---|---|
| `retouch` | the redeploy marker on the components `.baseline/tasks/01-product.TaskContract.yaml` names: `cloudflare-r2`, `web`, `web-tests` |
| `git-init`, `stage`, `rebrand` | the tree becomes a repository, then the product's |
| `orun-workspace` | intent.yaml's `workspace:` becomes the product's (or `ws_SET_ME`, which fails loudly) |
| `work-tree` | intent.yaml's `work:` block — this repository's epics and tasks — is removed |
| `promotion`, `dev-lanes` | prod's promotion gate and dev's push-to-main activation deferred until `02-docs` |
| `restage`, `rebrand-verify` | the sweep: no identity of this baseline left anywhere |
| `repo` | `orun.repo/ensure@v1` creates `<githuborg>/<reponame>` (or finds it) |
| `link` | the repository becomes the workspace's; `orun cloud check` is the gate |
| `secrets` | `orun.integrations/reconcile@v1`, the three keys in one hook, created side by side: `CLOUDFLARE_API_TOKEN` from the `workers-deploy` template (Workers Scripts and KV Storage write: the Worker's deploy — it cannot touch R2); `CLOUDFLARE_R2_TOKEN` from `r2-data` (Workers R2 Storage Write: the R2 root's apply, which binds it as its `CLOUDFLARE_API_TOKEN`); `CLOUDFLARE_ACCOUNT_ID`, the connection fact both bind |
| `task` | finds the phase's task and yields its key — waiting, if it must, for the background set-up |
| `land` | one PR bound to the task, its commit checked in the box first (`checks: local`: `orun validate`, then `orun plan` as the PR and as the merge would plan it, under a second); merged without waiting for the PR's CI |
| `converge` (await) | `orun.run/watch@v1` on the merge commit's run, read every 5 s; resumes it up to three times |
| `verify` (await) | `orun.http/probe@v1` on both workers.dev URLs |

## What the convergence does

`orun plan --changed` on the merge plans, with dev's push activation and the
promotion gate deferred:

| lane | waits on | does |
|---|---|---|
| `cloudflare-r2 · stage` / `· prod` | nothing | `terraform apply` of `stg-<reponame>-stage` / `prod-<reponame>-prod` with the `r2-data` token, adopting a bucket of that name if one exists (`adopt.tf`), then lease-publishes `WIRING_CLOUDFLARE_R2` = `{r2_bucket_name}` on that environment |
| `stage · web` / `prod · web` | that environment's R2 apply (`dependsOn: cloudflare-r2`, `mode: enforced` on main) | resolves `WIRING_CLOUDFLARE_R2_<ENV>` as it starts, renders `wrangler.jsonc` with the real bucket name, copies the dashboard into place, pushes the sign-in to the Worker when one is stored (`BASIC_AUTH_USERNAME`, `BASIC_AUTH_PASSWORD`, optional), deploys `<reponame>-web-<env>` with the `workers-deploy` token, and smoke-tests it: `/api/health` must answer `"ok":true` — the Worker listed its bucket through the binding, which only this Worker can — and `/` must serve the dashboard. Nothing is written to the bucket |

Stage and prod run side by side. `web-tests` verifies on dev only, on a
pull request. The landing's own pull request runs `plan` alone, and nothing
waits for it — the same plan ran in the box before the push: the baseline's
own CI installed, type-checked, linted, tested and built this exact tree
before the tag was cut.

## Verified

The convergence run for the merge commit is green — the explorer's deploys
resolved `WIRING_CLOUDFLARE_R2` from stage and prod, where every later run
reads it; `https://<reponame>-web-{stage,prod}.<subdomain>.workers.dev`
answer.

## Troubleshooting

| symptom | cause → fix |
|---|---|
| parks on the `providers` probe | GitHub (on the repository's owner) or Cloudflare is not connected to the workspace. Connect it (console → Integrations), then re-run the phase — the probe is a wait, not a failure |
| stops at `link` | the repository is not linked to the workspace and the credential cannot link it. Allow-list it (console → Settings → Git repos) and re-run the phase |
| `land`: `the landing's own check failed — orun plan for …` | the placed tree does not plan; the next line is orun's error. Nothing was pushed. Fix it and re-run the phase |
| R2 lane: `Please enable R2 through the Cloudflare Dashboard` (code 10042) | R2 is not enabled on the account. Enable it once (dashboard → R2 — the free tier needs no plan change, but Cloudflare asks for it to be switched on), then re-run the phase |
| R2 lane: the bucket name is taken | `adopt.tf` imports a bucket of the same name that this account owns; if it was removed, restore it. Two products with the same `reponame` in one account share a name — use a distinct `reponame` |
| R2 lane: Authentication error (10000) | the `r2-data` token was not minted with Workers R2 Storage Write — the connection's token lacks it. Re-issue it with the permission groups the console's Connect recipe lists, re-connect, re-run the phase |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts write; same fix |
| web lane fails resolving `WIRING_CLOUDFLARE_R2_<ENV>` | that environment's R2 apply failed or never ran — read its lane; the web lane waits on it, so it shows as not run on a fresh failure |
| smoke fails: the delivery route answers 500 | the Worker has no bucket bound — the rendered `wrangler.jsonc` lost its `r2_buckets` entry, or the template's token names the wrong key |
| web lane `build-app`: `wire: missing wiring documents` | the job started without the document — the `dependsOn` edge is gone from `apps/web/component.yaml`, or the secretEnv names the wrong key |
| web lane `verify-app-structure`: `test -f wrangler.jsonc` fails | `apps/web/wrangler.jsonc` is not committed (an old `.gitignore` entry); render it with `pnpm run wire:fixture` and commit it |
| smoke: `/api/health` answers 503 | the Worker cannot list its bucket — the binding names a bucket that is gone. Re-run the phase: the R2 root re-applies and the build renders the name again |
| smoke fails right after the FIRST deploy | workers.dev route propagation; the composition retries the first deploy and the smoke with backoff (stack-tectonic ≥ 0.19.0). A convergence resume clears what is left |
| the watch says green, the probe says 404 | another workflow ran on the push and the watch took its run. Only `ci.yml` may run on a push to main |
| convergence failed AFTER the PR merged; re-running lands nothing | the hooks did not run (`--run-hooks`), or the contract names no component — `node tooling/bootstrap/retouch.mjs --check --affects .baseline/tasks/01-product.TaskContract.yaml` in the site's tree says which |
