// The bindings wrangler.jsonc declares, as the Worker sees them — and the two
// optional Worker secrets (src/config.ts).
interface CloudflareEnv {
  bucket: R2Bucket;
  ASSETS: Fetcher;
  BASIC_AUTH_USERNAME?: string;
  BASIC_AUTH_PASSWORD?: string;
}
