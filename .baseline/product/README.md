# r2-explorer

A file manager for a Cloudflare R2 bucket —
[R2-Explorer](https://www.npmjs.com/package/r2-explorer)'s Google
Drive-style interface: folders, drag-and-drop and multipart uploads,
in-browser previews of images, PDFs, text, Markdown and CSV, in-place
editing, metadata — on **Cloudflare Workers + Static Assets**, over a bucket
that Terraform provisions per environment. Ported from Cloudflare's
[R2 Explorer template](https://github.com/cloudflare/templates/tree/main/r2-explorer-template).

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The Worker: R2-Explorer, configured from its secrets, and a health route | `apps/web/src/index.ts`, `apps/web/src/config.ts`, `apps/web/src/health.ts` |
| The site's name (the dashboard's `<title>`) | `apps/web/src/site.ts` |
| The build: the package's prebuilt dashboard copied into Static Assets, titled | `apps/web/scripts/build-dashboard.mjs`, `apps/web/scripts/dashboard-title.mjs` |
| Bindings and deploy contract | `apps/web/wrangler.template.jsonc` + `wiring.fixture.json` (→ `wrangler.jsonc`), `component.yaml` |
| The sign-in, handed to the Worker as Worker secrets | `tooling/wire/worker-secrets.mjs` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
| Tests | `tests/web` (vitest: the configuration, the health route, the Worker through R2-Explorer over an in-memory bucket, the dashboard's title) |

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
pnpm --filter @app/web dev        # wrangler dev on http://localhost:8787, a local R2 bucket
cp apps/web/.dev.vars.example apps/web/.dev.vars   # then set both keys to sign in locally
```

Its name is `apps/web/src/site.ts` (the browser tab's title). The explorer
itself is upstream's package, pinned in `apps/web/package.json`: upgrade it
there, deliberately.

## Signing in

**The explorer is read-only until you set a sign-in**, as upstream ships it.
Anyone with the URL can browse the bucket and download what is in it; no one
can upload, move, rename or delete. Put nothing private in the bucket until
you have done this:

1. Store two secrets for each environment, in the workspace this product
   deploys from (console → the project → Secrets, or `orun secrets set <KEY> --env <env>`):
   `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`.
2. Redeploy (Deploy by hand, below). The deploy hands both to the Worker as
   Worker secrets — `wrangler secret bulk`, the values over stdin — so no
   file in the repository and no bundle holds them.

From then on every `/api/*` route — listing, downloading and every change —
asks for HTTP Basic authentication, and the signed-in user can make changes.
Both are needed: one alone leaves the explorer read-only. `/api/health` asks
for nothing, whatever the mode: it says whether the bucket answers and which
mode the explorer is in, and names no file. To go back to read-only, delete
both Worker secrets (dashboard → the Worker → Settings → Variables and
Secrets, or `wrangler secret delete`) and the Orun secrets with them.

Cloudflare Access, upstream's other way in, and Email Routing (mail delivered
into the bucket) are not set up here.

## How the bucket reaches the Worker

There is no storage key to configure. The Worker binds the bucket as
`bucket` (the name the dashboard shows it under), and the binding is the
credential. Its name is never hand-written:
`apps/web/wrangler.template.jsonc` names it as a wiring token, and
`wrangler.jsonc` is that template rendered — from `wiring.fixture.json`
(placeholder names) for local work and verification, and on every deploy
from the document the `cloudflare-r2` Terraform root publishes after its
apply (`WIRING_CLOUDFLARE_R2`, per environment). Edit the template, then
`pnpm run wire:fixture` and commit the render with the template.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The R2 bucket applies first, then
the explorer builds with that environment's bucket name and deploys — to
`stage`, then to `prod` once stage has converged on the same commit; `dev`
only verifies. The Worker is `r2-explorer-web-<env>` on your account's
workers.dev subdomain, and every deploy is smoke-tested over HTTP: the health
route must read the bucket through its binding and the dashboard's page must
be served. A pull request runs the same pipeline's verify lanes, with nothing
applied or deployed: the R2 bucket planned for stage and prod, the dashboard
built and the Worker dry-deployed for each environment, and the tests run.
They do not run the linter — run it before you push (Getting started, above).

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. Two
Cloudflare tokens — one that deploys Workers, one that manages R2 — and the
account id are brokered per run from the workspace's Cloudflare connection,
and the bucket names travel as Orun secrets, as does the sign-in when you set
it; nothing provider-shaped is stored in the repository or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after setting or
rotating the sign-in, say. A component with nothing to run in that
environment (a test suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the site deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`r2-explorer-web-prod` → Settings → Domains & Routes → Add → Custom
domain). The explorer builds no absolute links of its own, so nothing else
has to change; the repository names the domain in one place, `BASE_DOMAIN`
in `intent.yaml`, which the site was born with as the reserved placeholder
`r2-explorer.example.com`. Replace it with your domain in the same change
that records it.

## Credits

R2-Explorer is © 2023-2025 Gabriel Massadas, MIT — a dependency, its LICENSE
installed with it. The template is Cloudflare's, MIT — `apps/web/LICENSE`.
