# r2-explorer

Cloudflare's [R2 Explorer template](https://github.com/cloudflare/templates/tree/main/r2-explorer-template)
— [R2-Explorer](https://www.npmjs.com/package/r2-explorer), a Google
Drive-style interface over an R2 bucket: folders, drag-and-drop and
multipart uploads, in-browser previews, in-place editing, metadata — running
on **Cloudflare Workers + Static Assets**, with the bucket provisioned by
Terraform through [Orun](https://github.com/sourceplane/orun), read-only
until its owner stores a sign-in (then HTTP Basic authentication guards
every change) — and, at its last milestone (RX4), packaged as an **Orun
baseline**: one command taking a new product from nothing to live on stage
and prod, in its own repository, under its own name, in ONE landing.

This repository is being built in five steps, one pull request each: the
spec (RX0), the file manager on Workers (RX1), the R2 bucket from Terraform
(RX2), ready to instantiate (RX3), and the baseline (RX4). The design, the
milestones and the as-built status are in
[`specs/epics/r2-explorer`](specs/epics/r2-explorer/README.md).

## Credit

The app is Cloudflare's [`r2-explorer-template`](https://github.com/cloudflare/templates/tree/main/r2-explorer-template),
MIT-licensed (© 2018 Cloudflare, Inc.); the licence arrives with it, in
`apps/web/LICENSE`, at RX1. The explorer itself is the npm package
[R2-Explorer](https://www.npmjs.com/package/r2-explorer) (MIT, © 2023-2025
Gabriel Massadas), installed as a dependency.
