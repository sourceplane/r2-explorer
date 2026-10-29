// GET /api/health — the deploy's smoke reads this, and nothing else does.
//
// Answered by this Worker before R2-Explorer sees the request, so it needs no
// credentials whatever the explorer's mode. It lists ONE key of the bucket
// through the `bucket` binding — a bucket that is not bound, or that does not
// answer, is a 503 — and returns no key: whether the bucket holds anything is
// not something an anonymous caller learns here. Read-only.
import { modeOf, type ExplorerEnv } from "./config";
import { SITE_NAME } from "./site";

export type HealthEnv = ExplorerEnv & { bucket?: R2Bucket };

export async function health(env: HealthEnv): Promise<Response> {
  const headers = { "cache-control": "no-store" };
  try {
    if (!env.bucket) throw new Error("no bucket binding");
    await env.bucket.list({ limit: 1 });
  } catch {
    return Response.json(
      { ok: false, error: "The R2 bucket did not answer: is the `bucket` binding deployed?" },
      { status: 503, headers },
    );
  }
  return Response.json({ ok: true, name: SITE_NAME, bucket: "bucket", mode: modeOf(env) }, { headers });
}
