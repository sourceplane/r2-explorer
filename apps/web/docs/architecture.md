# web — architecture

Built by the turbo pipeline from `apps/web` and deployed with wrangler.

|                    |                                    |
| ------------------ | ---------------------------------- |
| Worker config      | `apps/web/wrangler.template.jsonc` |
| Entry              | `src/index.ts`                     |
| Compatibility date | `2026-10-01`                       |

## Bindings

| Binding  | Kind          | Source                                |
| -------- | ------------- | ------------------------------------- |
| `bucket` | R2 bucket     | `r2_bucket_name` from `cloudflare-r2` |
| `ASSETS` | Static assets | `dist/dashboard`                      |

Identifiers marked _from_ a component are filled in at deploy time from
that component's published outputs for the environment being deployed.

## Wiring

Resolved at deploy time from secrets the infrastructure lanes publish (names only):

- `WIRING_CLOUDFLARE_R2_PROD`
- `WIRING_CLOUDFLARE_R2_STAGE`

## Secrets resolved by the lane (names only)

- `BASIC_AUTH_PASSWORD` (optional)
- `BASIC_AUTH_USERNAME` (optional)
