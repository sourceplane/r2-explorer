// The Worker: R2-Explorer — upstream's Drive-style interface and API over the
// `bucket` R2 binding, its dashboard served from Static Assets (ASSETS) —
// configured from this environment's Worker secrets (./config.ts), beside one
// route of its own (./health.ts).
import { R2Explorer as explorer } from "r2-explorer";
import { configFor, type ExplorerEnv } from "./config";
import { health } from "./health";

export type Env = ExplorerEnv & {
  ASSETS: Fetcher;
  bucket: R2Bucket;
};

// One explorer per configuration. A Worker's secrets are fixed for the life of
// an isolate, so in practice it is built once; keyed anyway, so that a test
// (or a secret rotated under a warm isolate) never serves a stale one.
let built: { key: string; app: ReturnType<typeof explorer> } | undefined;

function explorerFor(env: Env) {
  const config = configFor(env);
  const key = JSON.stringify(config);
  if (!built || built.key !== key) built = { key, app: explorer(config) };
  return built.app;
}

export default {
  async fetch(request, env, ctx): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/api/health" && (request.method === "GET" || request.method === "HEAD")) {
      return health(env);
    }
    // The explorer is handed the two bindings it serves and nothing else. It
    // picks a bucket by the URL's `:bucket` segment (`env[name]`), so the
    // sign-in secrets — configuration, read above — never reach it as
    // "buckets". It types its env as "every binding is a bucket"; ASSETS is
    // not, and it skips whatever has no get/put.
    const bindings = { ASSETS: env.ASSETS, bucket: env.bucket };
    return explorerFor(env).fetch(request, bindings as never, ctx);
  },
} satisfies ExportedHandler<Env>;
