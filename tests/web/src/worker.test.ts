import { describe, expect, it } from "vitest";
import worker, { type Env } from "@/src/index";
import { fakeBucket, json } from "./fake-bucket";

// The Worker end to end over an in-memory bucket: its own health route, then
// R2-Explorer itself (the real package), configured from the secrets.
const ctx = { waitUntil() {}, passThroughOnException() {}, props: {} } as unknown as ExecutionContext;
const assets = { fetch: async () => new Response("<div id=q-app></div>", { headers: { "content-type": "text/html" } }) };

function envWith(extra: Partial<Env> = {}, objects: Record<string, string> = { "notes/hello.txt": "hello" }) {
  return { ASSETS: assets as unknown as Fetcher, bucket: fakeBucket(objects) as unknown as R2Bucket, ...extra } as Env;
}
const call = (env: Env, path: string, init: RequestInit = {}) =>
  worker.fetch(new Request(`https://files.example${path}`, init) as never, env, ctx);
const basic = (u: string, p: string) => ({ authorization: `Basic ${btoa(`${u}:${p}`)}` });
const signedIn = { BASIC_AUTH_USERNAME: "sam", BASIC_AUTH_PASSWORD: "s3cret" };

describe("the Worker (apps/web/src/index.ts)", () => {
  it("answers /api/health itself, whatever the sign-in", async () => {
    for (const env of [envWith(), envWith(signedIn)]) {
      const res = await call(env, "/api/health");
      expect(res.status).toBe(200);
      expect((await json(res)).ok).toBe(true);
    }
  });

  it("with no secrets: a read-only explorer that lists the bucket and refuses changes", async () => {
    const env = envWith();
    const info = await call(env, "/api/server/config");
    expect(info.status).toBe(200);
    const body = await json(info);
    expect(body.config.readonly).toBe(true);
    expect(body.buckets).toEqual([{ name: "bucket" }]);

    const list = await call(env, "/api/buckets/bucket?limit=10");
    expect(list.status).toBe(200);
    expect((await json(list)).objects.map((o: { key: string }) => o.key)).toEqual(["notes/hello.txt"]);

    const folder = await call(env, "/api/buckets/bucket/folder", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ key: btoa("new-folder") }),
    });
    expect(folder.status).toBe(401);
    expect(JSON.stringify(await json(folder))).toContain("ReadOnly");
    expect((env.bucket as unknown as ReturnType<typeof fakeBucket>).objects.has("new-folder/")).toBe(false);
  });

  it("with both secrets: every /api route asks for them, and the signed-in user may change things", async () => {
    const env = envWith(signedIn);
    expect((await call(env, "/api/server/config")).status).toBe(401);
    expect((await call(env, "/api/buckets/bucket", { headers: basic("sam", "wrong") })).status).toBe(401);

    const info = await call(env, "/api/server/config", { headers: basic("sam", "s3cret") });
    expect(info.status).toBe(200);
    const body = await json(info);
    expect(body.config.readonly).toBe(false);
    expect(body.auth).toEqual({ type: "basic-auth", username: "sam" });
    // The explorer never echoes the credentials it was configured with.
    expect(JSON.stringify(body)).not.toContain("s3cret");

    const folder = await call(env, "/api/buckets/bucket/folder", {
      method: "POST",
      headers: { "content-type": "application/json", ...basic("sam", "s3cret") },
      body: JSON.stringify({ key: btoa("reports") }),
    });
    expect(folder.status).toBe(200);
    expect((env.bucket as unknown as ReturnType<typeof fakeBucket>).objects.has("reports/")).toBe(true);
  });

  it("never offers its secrets to the explorer as buckets", async () => {
    const env = envWith(signedIn);
    const info = await call(env, "/api/server/config", { headers: basic("sam", "s3cret") });
    expect((await json(info)).buckets).toEqual([{ name: "bucket" }]);
    const res = await call(env, "/api/buckets/BASIC_AUTH_PASSWORD", { headers: basic("sam", "s3cret") });
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(await res.text()).not.toContain("s3cret");
  });

  it("exports no email handler (Email Routing is left out)", () => {
    expect((worker as Record<string, unknown>).email).toBeUndefined();
  });
});
