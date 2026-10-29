# Epic: r2-explorer (RX)

**Cloudflare's R2 Explorer template is a configuration of one npm package: [R2-Explorer](https://www.npmjs.com/package/r2-explorer), a Google Drive-style interface over an R2 bucket — folders, drag-and-drop and multipart uploads, in-browser previews of images, PDFs, text, Markdown and CSV, in-place editing, metadata. Its Worker is `R2Explorer({ readonly: true })`, its dashboard the package's prebuilt single-page app served as Static Assets, its bucket one `wrangler r2 bucket create` away. Here the bucket is per environment from Terraform; the Worker's configuration follows its owner's sign-in — read-only with none, as upstream ships it, HTTP Basic authentication and changes allowed with both `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`; and the wrangler config is rendered per environment from the R2 root's wiring document.**

The port keeps the package, its dashboard, its API and its read-only default unchanged. It adds the monorepo wrapper, `/api/health` (the smoke's and the probes' bucket check), the dashboard's copy into the Worker's assets with the product's name as its title, a test package that drives the real R2-Explorer over an in-memory bucket, the R2 Terraform root, the deploy contract and the sign-in's path to the Worker — and makes the repository an Orun baseline.

## Status

| Field | Value |
|-------|-------|
| Status | ✅ RX0–RX4 shipped ([#1](https://github.com/sourceplane/r2-explorer/pull/1)–[#5](https://github.com/sourceplane/r2-explorer/pull/5); RX4 tagged `baseline-v1`). A Terraform apply and a live deploy are proven only by a live bootstrap (risk RX-G) |
| Cluster | **RX** (RX0–RX4) |
| Owner(s) | `apps/web` (`src/index.ts`, `src/config.ts`, `src/health.ts`, the dashboard's build, the wrangler template) · `tests/web` · `infra/terraform/cloudflare-r2` |
| Builds on | `blob-starter` (the Cirrus R2 root `cloudflare-r2`, its wiring render and its one-landing bootstrap); `ai-artifacts` (optional Orun secrets handed to the Worker as Worker secrets) |
| Upstream | [cloudflare/templates `r2-explorer-template`](https://github.com/cloudflare/templates/tree/main/r2-explorer-template) (MIT, © 2018 Cloudflare, Inc.), over [R2-Explorer](https://www.npmjs.com/package/r2-explorer) 1.1.10 (MIT, © 2023-2025 Gabriel Massadas) |
| Changes | The configuration from the Worker's secrets (read-only, or Basic auth with changes); Cloudflare Access and Email Routing left out; the dashboard copied into `dist/dashboard`, its title the product's; `/api/health`; the wrangler config rendered per environment; tests, the R2 root, the deploy contract |
| Decisions locked | (1) R2-Explorer stays upstream's package, pinned exactly, its dashboard copied not rebuilt (design §2). (2) Read-only until BOTH sign-in keys are stored (design §3). (3) The sign-in is two optional Orun secrets, pushed to the Worker as Worker secrets; the build never sees them (design §3). (4) No Cloudflare Access, no Email Routing (design §6). (5) The bucket before the Worker on main: cloudflare-r2 → web, enforced; advisory on pull requests. |
| Gate | RX2 applies only with a linked workspace (a Cloudflare connection with R2 enabled); verified by `terraform validate` and, from RX4, the offline end-to-end tier. |
| Shipped as | `baseline-v1` ([#5](https://github.com/sourceplane/r2-explorer/pull/5)); proven offline (Baseline CI: the built Worker served under `wrangler dev` over a local bucket, driven read-only and then signed in), deploy gated until a workspace is linked |

## Read order

1. `design.md` — what maps to what, the configuration, the bindings, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| RX0 — the spec | this doc set, the task contracts, the repository's intent, CI and tooling | merged on `main` |
| RX1 — the file manager on Workers | `apps/web`, the rendered wrangler config, `tests/web`, the Worker-secrets step | typecheck, lint, test and build green; the Worker serves the explorer over the binding, read-only and signed in |
| RX2 — the R2 bucket from Terraform | `infra/terraform/cloudflare-r2` | the root validates; its wiring key matches the template |
| RX3 — ready to instantiate | README, as-built status | a reader can run, test, preview, deploy and sign in |
| RX4 — a baseline | card, build document, rename engine, bootstrap tooling, the product's README and context pack, component docs, tests, `baseline.yml` / `tag.yml` | a new product goes from nothing to live on stage and prod in one landing; Baseline CI green; tagged `baseline-v1` |
