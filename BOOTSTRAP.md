# BOOTSTRAP — a new product from this baseline, in one landing

How to go from **nothing** to a **file manager for an R2 bucket live on
stage and prod, its buckets applied, documented**, with ONE provider consent.

There is one artifact: **`repo-blueprint.yaml`**. It declares what to place,
in what order, what each phase needs first, and what to say while it runs.
`orun new` is the whole runtime — the phases below are its `--phase` names,
not separate workflows. The console card the platform renders is
**`blueprint.yaml`**; it names the build document and states the inputs, the
brokered secrets and the programme, and `testing/manifest.test.sh` holds it
to what the build document does.

Target wall-clock: **about six minutes** — an estimate summed from the
phases (5 + 1) until a bootstrap measures it; no build of this baseline has
been timed. The shape: the task set-up in the background while ONE landing
is placed, branded and checked in the box (`orun validate` and `orun plan`,
no runner waited for), then one convergence — the R2 bucket applied on stage
and prod, then the explorer built with its name and deployed, stage and prod
side by side — then a short docs landing that restores the promotion gate.

## 0. What you need

- GitHub org access (repository creation) and a machine with `git`, `node`
  (≥ 22), `pnpm` (10.12.1), `python3` with PyYAML, `curl`, and the `orun`
  CLI **≥ v2.88.0** — the floor for RUNNING the bootstrap (the phase overlay,
  landings that commit per phase, `githubOwner` on the doctor probe, a probe
  deferred for a project not yet created, `from: workspace`, the deploy
  credentials minted in one `secrets` reconcile, the task set-up run in the
  background (`background: true`), and landings checked in the box before
  they merge (`checks: local`)). The product's own `ci.yml` pins its lanes
  separately (v2.78.4).
- A Cloudflare account (the free plan is enough for one Worker with static
  assets and an R2 bucket per environment) with **R2 enabled** — once per
  account, dashboard → R2; Cloudflare asks for it to be switched on even on
  the free tier, and the bucket's apply fails until it is — and its
  **Account API token** with Workers Scripts Write and Workers R2 Storage
  Write (the console's Connect recipe lists the exact permission groups). It
  is the ONLY provider credential this baseline needs: the platform mints
  two scoped tokens from it, `workers-deploy` for the Worker's deploy and
  `r2-data` for the bucket's apply, because the deploy token deliberately
  cannot touch R2. The explorer needs no storage key at all: the running
  Worker reaches its bucket through its R2 binding. Its sign-in
  (`BASIC_AUTH_USERNAME`, `BASIC_AUTH_PASSWORD`) is optional and not part of
  the build: until both are stored the explorer is read-only (section 4).
- An Orun Cloud workspace for the product — `orunWorkspace`, or the
  workspace the build runs in (ORUN_WORKSPACE) when that is unset — with an
  **admin-role API key** for headless runs (secret writes below admin are
  masked as `not_found`).
- **The repository allow-listed in the workspace** (console → Settings → Git
  repos), unless the credential can write links. `01-product`'s `link` step
  stops and names the fix if it is not.

## 1. One command: `--resume`

The whole bootstrap, unattended. `--resume` places every phase not already
derived as done, in order, honouring each phase's barrier:

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/r2-explorer
cd r2-explorer

orun new --blueprint repo-blueprint.yaml \
  --out ~/sites/acme-files --run-hooks --resume \
  --set reponame=acme-files --set productname="Acme Files" \
  --set githuborg=acme-inc \
  --set orunWorkspace=ws_XXXXXXXX \
  --set subdomain=<workers-dev-subdomain>
```

`subdomain` is the workers.dev subdomain of the Cloudflare account you deploy
into (Workers & Pages → your subdomain). A build started from the console, or
with `orun baseline new --from bst_…`, never asks for it: the platform reads
it from the workspace's Cloudflare connection, the same one the deploy tokens
mint from. Only a hand-run build like this one passes it.

**`--run-hooks` is the difference between placing files and bootstrapping a
product.** Without it `orun new` writes the tree and stops: no repository, no
landing, no convergence watch, no probe. That is deliberate — it is what
makes the offline bootstrap in `testing/` possible with no workspace and no
provider.

`--resume` is safe to re-run from anywhere, a fresh container with a fresh
`--out` included: **phase state is derived from the tree, never stored.** A
phase whose files are present but branded derives as `drifted`, and
`--resume` leaves it placed rather than reverting the product's identity.

## 1b. Or phase by phase

| phase | what it lands | verified by |
|---|---|---|
| `01-product` | the repository, created and linked; the WHOLE product in one PR — intent, CI, tooling, identity, the R2 root, the explorer and its tests; the brokered Cloudflare secrets (the deploy token, the R2 token, the account id) | its commit validated and planned in the box (as the PR and as the merge), then merged; the convergence green (R2 applied, then the explorer — which resolves `WIRING_CLOUDFLARE_R2` — built, deployed, smoke-tested on `/api/health`, which lists its bucket); both workers.dev URLs answering |
| `02-docs` | `ai/context/deployment.md` from probed facts; prod's promotion gate and dev's push lanes restored | the render's own probes, recorded; the commit checked in the box and merged |

```bash
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-files --run-hooks \
  --phase 01-product --values ~/acme-files.values.yaml
# … then 02-docs
```

`02-docs` reads the identity back from `.rebrand/values.json` in the placed
tree, but the blueprint's **required** inputs — `reponame`, `productname`,
`githuborg` — are validated before anything runs, so pass them every time (a
`--values` file is easier). The domain is not one of them: the site goes live
on workers.dev, and `productdomain` defaults to empty, which brands the
reserved placeholder `<reponame>.example.com` into `BASE_DOMAIN` for an owner
to replace when they attach a domain (README, "Custom domain"). Pass
`--set productdomain=` only for a site that already has its domain.
The full guide, one page per phase: [docs/phases/README.md](docs/phases/README.md).

| flag | what it does |
|---|---|
| `--status` | derives and prints every phase's state and writes nothing. It parses the document, validates each hook against the action registry and compiles every template; it needs no credential and no network |
| `--phase <name>` | places exactly that phase; its `requires.phases` still gates |
| `--until <name>` | places every phase through that one and stops |

What lands in the product is PRODUCT-ONLY: the app, its R2 root, its tests,
its CI, its tooling, its README and its two context pages. None of this
repository's machinery (`.baseline/`, the blueprints, `tooling/rebrand`,
`tooling/bootstrap`, `hooks/`, `testing/`, `docs/phases/`, `specs/`,
`tasks/`, this file) ships, and no file that ships names one of them. That
promise is a test: `testing/leak.test.sh` derives what every phase would
place and gates the set and its sources, and `testing/placement.test.sh`
gates the same rules over a placed, branded tree.

## 2. Why one landing is safe: the plan carries the order

The bucket must exist before the Worker that binds it: the Worker's
`wrangler.jsonc` carries the bucket name, rendered in its build from the
wiring document the R2 root publishes after its apply. That order used to
need landings of its own. It does not, because the product's plan holds it:

- `apps/web/component.yaml` declares `dependsOn: cloudflare-r2` with
  `mode: enforced`, and `modeRules` making it advisory on
  `github-pull-request`. On the merge the Worker's deploy waits for its
  environment's apply; on a pull request nothing deploys, so nothing waits.
- A job resolves its secrets when it STARTS, so `WIRING_CLOUDFLARE_R2_<ENV>`
  is there when the deploy begins.
- The deploy resolves the document from the place every later run looks
  (its `component.yaml` secret refs), so a green convergence already says it
  is there: a missing one fails its lane. There is no separate check.

`testing/phases.test.sh` fails if a component that reads a wiring document
does not wait for its publisher this way; `testing/placement.test.sh` plans
the product's own merge and asserts the R2 lanes run first.

## 3. Headless / container mode

The blueprint's source is this repository (`sources: [{kind: dir, path: .}]`),
so the container contract is a shallow clone at a pinned tag plus two
tokens:

```bash
export ORUN_TOKEN=…          # orun auth, headless
export GITHUB_TOKEN=…        # fine-grained PAT (below)

git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/r2-explorer
cd r2-explorer
orun new --blueprint repo-blueprint.yaml \
  --out /work/acme-files --run-hooks --resume --progress json \
  --values /work/acme-files.values.yaml
```

| requirement | detail |
|---|---|
| `GITHUB_TOKEN` | fine-grained PAT: **read** on this repository; on the PRODUCT's repository **contents write**, **pull-requests write**, **actions read+write** (`orun.run/watch@v1` resumes runs with `gh run rerun`), **checks read**; **repository create** on the owner if `01-product` creates it (or pre-create it — supported) |
| classic token caveat | a classic PAT or gh OAuth token also needs the `workflow` scope to push `.github/workflows/` |
| pinning | the clone's `--branch <tag>` pins everything: the blueprint, its modules and its hooks' scripts all come from that one commit |

## 4. After the product is live

- **Allow changes**: store `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`
  for each environment (console → Secrets, or `orun secrets set <KEY> --env <env>`) and re-run
  its deploy (Orunbase's Deploy button, or Run workflow on `main`). The build
  pushes them to the Worker as Worker secrets; from then on every `/api`
  route asks for HTTP Basic authentication and the signed-in user may
  upload, move, rename and delete. With neither, the explorer is read-only —
  and public: anyone with the URL can browse and download the bucket, so put
  nothing private in it until the sign-in is stored. The product's README
  says so first.
- **Rename it**: the dashboard's `<title>` is `apps/web/src/site.ts`. Every
  merge to `main` redeploys.
- **Add a binding** (D1, KV, another bucket): a Terraform root that
  lease-publishes `WIRING_<ROOT>`, a token in `wrangler.template.jsonc`, its
  fixture entry, and in `apps/web/component.yaml` the root in the build's
  `--components`, the `WIRING_<ROOT>_<ENV>` secretEnv and an enforced
  `dependsOn` on it. `ai/context/operations.md` in the product says the same.
- **Custom domain**: attach it to the Worker in Cloudflare (the product's
  README, "Custom domain"). There is no domain phase: attaching a domain
  needs zone permissions the brokered `workers-deploy` token does not carry.
  Nothing in the repository changes — the dashboard calls its API on the
  origin it was served from.
- **Refresh the record**: re-run `--phase 02-docs`; it is idempotent.

## 5. Testing this baseline

`.github/workflows/baseline.yml` runs three tiers on every pull request, and
each runs locally the same way:

```bash
for t in manifest phases coverage rebrand retouch bootstrap-defer wire; do bash testing/$t.test.sh; done
bash testing/leak.test.sh        # needs orun
bash testing/placement.test.sh   # needs orun >= ci.yml's pin, node, pnpm: the offline bootstrap and the product's own plan
bash testing/e2e.test.sh         # + network for pnpm: the product built in the job tree, dry-deployed and served
```

The offline bootstrap (`testing/lib/bootstrap.sh`) places both phases in
order and finishes each with the blueprint's OWN `run:` hooks — read out of
`repo-blueprint.yaml`, not transcribed — so the retouch marker, the rebrand,
the re-tenant, the deferrals and their restore, and the deployment record
all run exactly as a real bootstrap runs them. Only the platform's typed
actions (task, repo, link, reconcile, land, watch, probe) are stood in for,
a landing becoming a commit. What no offline test
can do is the platform's half: the bucket applied for real (the R2 root
is held to `terraform validate`), the token minted, the deploy, the probes.
The explorer itself is served for real (`wrangler dev`, a local bucket) and
driven read-only, then signed in.

## 6. Cutting a baseline tag (maintainers)

Every product built from this repository resolves a `baseline-vN` tag, so
the tag is cut by a workflow rather than by hand:

```bash
gh workflow run tag.yml -f version=baseline-v1          # from main
gh workflow run tag.yml -f version=baseline-v1 -f ref=<sha>
```

It refuses a version that is not `baseline-v<N>` and a tag that already
exists: a baseline tag is never moved. Then move the registry row in
orun-cloud's `infra/baselines-registry/baselines.yaml` by pull request —
after the tag exists, because the registry's sync fetches `blueprint.yaml`
at the tag and refuses the whole catalogue if it 404s.

## Troubleshooting

| Symptom | Cause → fix |
|---|---|
| `01-product` parks: `waiting for github for <org>` | the workspace's GitHub connection is to another account. Connect the App installation on `<org>` (console → Integrations → GitHub), then `--resume` |
| `01-product` waits on the `providers` probe, then stops | Cloudflare is not connected. Connect it (console → Integrations), then re-run the phase — the probe is a wait, not a failure |
| `01-product` stops at `link` | the repository is not linked to the workspace and the credential cannot link it. Allow-list it (console → Settings → Git repos) and re-run the phase |
| Secret WRITE fails `not_found` while listings work | the API key's role is below admin; re-mint it with the admin role |
| R2 lane: `Please enable R2 through the Cloudflare Dashboard` (code 10042) | R2 is not switched on for the account — it must be, once per account, even on the free plan. Enable it (dashboard → R2 → Get started), then re-run `01-product` |
| R2 lane: Authentication error (10000) | the `r2-data` token lacks Workers R2 Storage Write — the connection's token does not hold it. Re-issue it, re-connect, re-run `01-product` |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts write; same fix |
| R2 lane: the bucket name is taken | `adopt.tf` imports a bucket of the same name the account owns; restore it if removed. Two products with one `reponame` in one account share names — pick another `reponame` |
| web lane fails resolving `WIRING_CLOUDFLARE_R2_<ENV>` | that environment's R2 apply failed — read its lane; the web lane waits on it |
| web lane: `WIRING_CLOUDFLARE_R2` not found | that environment's R2 apply published nothing: the R2 component lost its `secretOutputs`, or its lane was not in the plan. Re-run the phase; its retouch marker re-plans the R2 root |
| `land` stops: `the landing's own check failed — orun plan for …` | the product's tree does not plan — the line after it is orun's own error (an unknown component type, a composition that does not resolve). Nothing was pushed. Fix the tree (or the baseline) and re-run the phase |
| `land` waits on CI after all | the product's repository requires a status check on `main` (branch protection or a ruleset), so GitHub refused the early merge; the landing waits for the check as a `checks: ci` landing would, then merges |
| Convergence failed AFTER the PR merged; re-running lands nothing | expected on its own — the files are on main. Re-run the phase (`--phase 01-product`, `--redo 01-product`, or the console's Retry): its `retouch` hook gives the landing a diff and the R2 root and the explorer re-plan |
| The product's `intent.yaml` says `workspace: ws_SET_ME` | `orunWorkspace` was empty and the build ran outside a workspace; set it and re-run `01-product` |
| A bootstrap stopped before `02-docs`; prod no longer waits on stage | the gate is deferred, not dropped: run `02-docs`, or `node tooling/bootstrap/promotion.mjs --restore --file <product>/intent.yaml` |
| `✕ input "productname" is required` | all three required inputs (`reponame`, `productname`, `githuborg`) must be set on every invocation, single-phase ones included |
| `unknown flag: --phase`, `has no parameter "checks"`, `has no parameter "secrets"` or another parse error in the blueprint | the CLI is below the v2.88.0 floor |
| web lane `verify-app-structure` fails on `wrangler.jsonc` | the config is not committed. It is the fixture render of `wrangler.template.jsonc`: `pnpm run wire:fixture` and commit it |
| web lane smoke: `/api/health` answers 503 `{"ok":false,…}` | the Worker is up but cannot list its bucket — the `bucket` binding names a bucket that is gone. Re-run `01-product`: the R2 root re-applies and the build renders its name again |
| the explorer lets anyone upload | it does not: with no sign-in stored it is read-only, and the dashboard's upload is refused (`401`, `ReadOnly`). Store BOTH keys — with one, it stays read-only |
| signed in, every request answers `401` | the stored username or password is not what the browser sends. Re-store both and re-run the deploy; the build pushes them to `<repo>-web-<env>` |
| the convergence reported green, then `verify` got 404 | a second workflow ran on the push to main and the watch took its run. Only `ci.yml` may run on a push to main |
