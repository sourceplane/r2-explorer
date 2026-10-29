import { describe, expect, it } from "vitest";
import { health } from "@/src/health";
import { SITE_NAME } from "@/src/site";
import { fakeBucket, json } from "./fake-bucket";

// GET /api/health — what the deploy's smoke reads.
describe("the health route (apps/web/src/health.ts)", () => {
  it("lists one key through the binding and answers ok, naming no key", async () => {
    const bucket = fakeBucket({ "private/report.pdf": "x" });
    const res = await health({ bucket: bucket as unknown as R2Bucket });
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("no-store");
    const body = await json(res);
    expect(body).toEqual({ ok: true, name: SITE_NAME, bucket: "bucket", mode: "read-only" });
    expect(JSON.stringify(body)).not.toContain("report.pdf");
    expect(bucket.calls).toEqual(["list"]);
  });

  it("says read-write once both secrets are set", async () => {
    const res = await health({
      bucket: fakeBucket() as unknown as R2Bucket,
      BASIC_AUTH_USERNAME: "sam",
      BASIC_AUTH_PASSWORD: "s3cret",
    });
    expect((await json(res)).mode).toBe("read-write");
  });

  it("is a 503 when the bucket is not bound", async () => {
    const res = await health({});
    expect(res.status).toBe(503);
    expect((await json(res)).ok).toBe(false);
  });

  it("is a 503 when the bucket does not answer", async () => {
    const broken = { list: async () => Promise.reject(new Error("R2 down")) } as unknown as R2Bucket;
    const res = await health({ bucket: broken });
    expect(res.status).toBe(503);
    expect(JSON.stringify(await json(res))).not.toContain("R2 down");
  });
});
