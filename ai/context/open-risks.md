# r2-explorer — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/r2-explorer/risks-and-open-questions.md`; this page lists only
what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| RX-G | No live bootstrap yet: the repository created and linked, the two tokens minted, a real `terraform apply` of the bucket, the published wiring document, a real `wrangler deploy` with its Worker secrets, and the probes are all unproven | OPEN | One bootstrap from a tag against a workspace whose Cloudflare account has R2 enabled |

Accepted, and worth knowing before you change them: RX-A (read-only is
public, as upstream), RX-B (one shared HTTP Basic sign-in, no lockout),
RX-C (no Cloudflare Access), RX-D (no Email Routing), RX-I (R2 is switched
on per account by its owner), RX-J (the package and its dashboard are
upstream's, upgraded by a pin), RX-K (a custom domain is the owner's step).
Resolved: RX-E (the dashboard's `<title>`), RX-F (the slug is the package's
name), RX-H (secrets offered as buckets).
