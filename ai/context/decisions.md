# r2-explorer — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | R2-Explorer stays upstream's package, pinned exactly (1.1.10, `hono` 4.13.8 from its lockfile); the Worker mounts its app and the build copies its prebuilt dashboard | The template is a configuration of the package, not code of its own: a port that rewrote it would no longer be the template | `specs/epics/r2-explorer/design.md` §2 |
| 2 | Read-only by default; HTTP Basic sign-in and changes with BOTH `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` | Upstream ships `readonly: true` and tells its owner to edit the flag; here the flag follows the sign-in, so an explorer that allows changes always asks who is making them | design.md §3, risk RX-A |
| 3 | The sign-in is two OPTIONAL Orun secrets, pushed to the Worker as Worker secrets by the deploy (`wrangler secret bulk`); the build runs with both unset | Not part of the build's consent, never minted; the Worker reads them at request time, and no bundle, asset or log can hold them | design.md §3, risk RX-B |
| 4 | Cloudflare Access left out | An Access application is a Zero Trust resource no Orun composition provisions | design.md §6, risk RX-C |
| 5 | Email Routing left out; the Worker exports `fetch` only | No composition for Email Routing; it needs a zone the brokered tokens do not reach | design.md §6, risk RX-D |
| 6 | `/api/health` lists one key of the bucket and is the deploy's smoke and the record's probe | The one read-only route only this Worker, bound to its bucket, can answer — the dashboard alone would answer from Static Assets with no bucket at all | design.md §4 |
| 7 | R2-Explorer is handed only `ASSETS` and `bucket`, never the whole env | Its routes address a binding by the name in the URL (`/api/buckets/<binding>`) and its config lists every binding with `get` and `put`; with two bindings, the sign-in is out of every route's reach | design.md §3, risk RX-H |
| 8 | The slug `r2-explorer` is also the npm package's name: the rename engine protects every place the tree names the package (`UPSTREAM` in `tooling/rebrand/rebrand.mjs`) | A product renamed `acme-files` must still install and import `r2-explorer` | risk RX-F |
| 9 | `wrangler.jsonc` is rendered from the R2 root's wiring document per environment, and the fixture render is committed | The deploy lane checks the config exists before the build; the e2e tier diffs the committed render | design.md §4 |
| 10 | The R2 root applies with its own `r2-data` key (`CLOUDFLARE_R2_TOKEN`) | The `workers-deploy` token cannot touch R2 | design.md §4 |
| 11 | One landing (`01-product`) then the record (`02-docs`); `apps/web` `dependsOn: cloudflare-r2`, enforced on main, advisory on a pull request | The plan, not a landing boundary, orders the bucket before the Worker | design.md §5 |
| 12 | stack-tectonic 0.19.0 | The floor for the first-deploy retry and the smoke's backoff; the explorer has one job per lane, so 0.20.0's shared install would save nothing | `intent.yaml` |
| 13 | The console asks for no domain; an empty `productdomain` brands the placeholder `<reponame>.example.com`, and `subdomain` is read from the Cloudflare connection | The explorer goes live on workers.dev; attaching a domain is an owner's step | `blueprint.yaml`, risk RX-K |
