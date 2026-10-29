# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`r2-explorer/`](./r2-explorer/) | **RX** | In progress (RX3 shipped; RX4 next) | Cloudflare's R2 Explorer template — R2-Explorer, a file manager over an R2 bucket — on Cloudflare Workers with the bucket from Terraform, and an Orun baseline that instantiates it in one landing (RX4) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
