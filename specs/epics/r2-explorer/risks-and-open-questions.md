# r2-explorer — risks and open questions

## RX-A — Read-only is public (ACCEPTED)

With no sign-in stored, the explorer is upstream's default: `readonly: true`
and no authentication, so anyone with a workers.dev URL can list, preview
and download everything in the bucket. Nothing can change it — every write
is refused (`401`, `ReadOnly`, held by `tests/web` and the e2e tier) — but
nothing in it is private. Accepted because it is the template's own
behaviour and because the bucket is born empty: the product's README says
so first, under "Signing in", and its operating contract's "Who can do
what" table repeats it. An owner who wants the bucket private before it
holds anything stores the sign-in, which guards every `/api` route —
listing and downloading included.

## RX-B — One shared HTTP Basic sign-in (ACCEPTED)

`basicAuth` is one username and password, checked by R2-Explorer on every
`/api` request, with no lockout or rate limit of its own, sent by the
browser on every request (over HTTPS: workers.dev serves nothing else).
It is R2-Explorer's own guard and the only one a product can switch on with
secrets alone; a stronger one is Cloudflare Access (RX-C). Rotating it is
setting new values and redeploying; the deploy replaces the Worker's
secrets.

## RX-C — No Cloudflare Access (ACCEPTED)

Upstream's README points at Access (`cfAccessTeamName`) as the way to
secure an explorer. An Access application is a Zero Trust resource no Orun
composition provisions, and the brokered tokens carry no Access
permission, so the baseline cannot create one; it ships Basic auth instead.
An owner can add Access by hand (design §6).

## RX-D — No Email Routing (ACCEPTED)

R2-Explorer can store mail delivered by Email Routing. That needs a zone
with Email Routing enabled and a routing rule to the Worker — zone
resources no composition provisions. The Worker exports no `email` handler
and tells R2-Explorer `emailRouting: false`.

## RX-E — The dashboard's title (RESOLVED)

The dashboard is prebuilt; its `<title>` is the package's. The build sets
it to `SITE_NAME` in both of its pages (`index.html`, `spa/index.html`),
HTML-escaped, and fails if either has no `<title>` to set — so a package
upgrade that moves it breaks the build, not the brand. `tests/web` holds the
escaping (`Sam's Photos & Files`), the e2e tier the served page.

## RX-F — The slug is the package's name (RESOLVED)

This baseline's slug, `r2-explorer`, is also the npm package it depends
on. The rename engine renames the slug to the product's repository name
everywhere — so without a mask a product called `acme-files` would depend
on `acme-files: 1.1.10`, import from `"acme-files"` and copy a dashboard
from `node_modules/acme-files`, and would not install. `UPSTREAM` in
`tooling/rebrand/rebrand.mjs` protects the pinned dependency, the one
import, the package's `require.resolve`, its `node_modules` directory, its
npm link and Cloudflare's template's links; prose names the package
"R2-Explorer". `testing/rebrand.test.sh` holds every mask (and that the
slug anywhere else is still residue), `testing/placement.test.sh` holds a
placed product, and the e2e tier installs and builds one.

## RX-G — No live bootstrap yet (OPEN)

Everything short of the platform is proven on every pull request: the card
against the build, the blueprint read by the pinned orun, the leak gate, the
offline bootstrap with the blueprint's own hooks, the product's own plan
(cloudflare-r2 → web per environment, enforced on main, advisory on a pull
request), and the produced product installed, built in the job tree with a
sign-in planted in its environment and found in nothing it wrote,
dry-deployed with both bindings, served over a local bucket, smoke-tested,
and driven read-only and then signed in. NOT proven: the repository created
and linked, the three keys minted by `integrations/reconcile`, a real
`terraform apply` of the bucket (the root is held to `terraform validate`),
a real `wrangler deploy`, `wrangler secret bulk` against a deployed Worker,
and the probes of `/` and `/api/health`. Closes with one bootstrap from a
tag against a workspace whose Cloudflare account has R2 enabled (RX-I).

## RX-H — Secrets offered as buckets (RESOLVED)

R2-Explorer addresses a bucket by the binding name in the URL
(`/api/buckets/<binding>/…`) and lists, in `/api/server/config`, every
binding with `get` and `put` methods. Handed the Worker's whole env, its
routes would reach the sign-in's bindings by name. `src/index.ts` hands it
`{ ASSETS, bucket }` only; `tests/web` holds that the config offers one
bucket and that a request for the sign-in by name finds nothing, and the
e2e tier that `ASSETS` does not list.

## RX-I — R2 is switched on per account (OWNER PREREQUISITE)

Cloudflare asks for R2 to be enabled once per account (dashboard → R2),
even on the free plan; until it is, the R2 root's apply fails with "Please
enable R2 through the Cloudflare Dashboard" (code 10042) and the Worker,
which waits on it, does not deploy. It is a click no token can make.
`BOOTSTRAP.md` lists it under what you need and in its troubleshooting.

## RX-J — Upstream's package, upgraded by a pin (ACCEPTED)

The explorer's API and dashboard are the package's, pinned exactly
(R2-Explorer 1.1.10, and `hono` 4.13.8, the peer its dependencies need, at
upstream's lockfile's version). An upgrade is a pin bump and the tests:
`tests/web` drives the real package's routes (the bucket detection it
relies on included), and the build fails if the dashboard moves.

## RX-K — A custom domain is the owner's step (ACCEPTED)

The console asks for no domain; the explorer goes live on workers.dev and
an empty `productdomain` brands the placeholder `<reponame>.example.com`.
Attaching a domain needs zone permissions the brokered `workers-deploy`
token does not carry; the product's README ("Custom domain") says how.
