# r2-explorer — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a product built from it;
the two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Cloudflare's R2 Explorer template — R2-Explorer, a Google Drive-style file
manager over an R2 bucket — on Cloudflare Workers + Static Assets, with the
bucket Terraform provisions, packaged as an Orun baseline: `orun new
--blueprint repo-blueprint.yaml` builds a new product in its own repository
and takes it to live on stage and prod in one landing (`01-product`: the
bucket applied, then the Worker deployed), then records what went live
(`02-docs`). It ships read-only, as upstream does; its owner's sign-in
(two optional Orun secrets) turns on HTTP Basic authentication and changes.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` (RX4 — the first baseline) |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI — the built Worker served under `wrangler dev` over a local bucket and driven read-only, then signed in (a file uploaded, listed, read back and deleted); a live bootstrap from a tag is still to come (risk RX-G) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/r2-explorer/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/r2-explorer/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/r2-explorer/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `tests/web/docs/`, `infra/terraform/cloudflare-r2/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one product from `baseline-v1` against a workspace whose
   Cloudflare account has R2 enabled (RX-I), store its sign-in, and record
   its timings (closes RX-G).
