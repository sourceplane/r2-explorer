// A response's JSON, untyped: the tests read fields of upstream's answers.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const json = async (res: Response): Promise<any> => res.json();

// An in-memory R2 bucket: what R2-Explorer's list, read and write routes call,
// and nothing more. Keys are listed in order, as R2 lists them.
type Stored = { body: Uint8Array; httpMetadata?: Record<string, string>; customMetadata?: Record<string, string> };

export function fakeBucket(initial: Record<string, string> = {}) {
  const objects = new Map<string, Stored>();
  for (const [k, v] of Object.entries(initial)) objects.set(k, { body: new TextEncoder().encode(v) });
  const meta = (key: string, o: Stored) => ({
    key,
    size: o.body.byteLength,
    etag: "etag",
    httpEtag: '"etag"',
    uploaded: new Date(0),
    httpMetadata: o.httpMetadata ?? {},
    customMetadata: o.customMetadata ?? {},
    writeHttpMetadata(h: Headers) {
      for (const [k, v] of Object.entries(o.httpMetadata ?? {})) h.set(k, v);
    },
  });
  const calls: string[] = [];
  const bucket = {
    calls,
    objects,
    async list(opts: { limit?: number; prefix?: string; delimiter?: string } = {}) {
      calls.push("list");
      const prefix = opts.prefix ?? "";
      const keys = [...objects.keys()].filter((k) => k.startsWith(prefix)).sort();
      const limited = keys.slice(0, opts.limit ?? 1000);
      return {
        objects: limited.map((k) => meta(k, objects.get(k)!)),
        delimitedPrefixes: [] as string[],
        truncated: limited.length < keys.length,
      };
    },
    // A function expression, not method shorthand: R2-Explorer recognises a
    // bucket binding by `get.toString()` and `put.toString()` containing
    // "function", as a real binding's native methods do.
    get: async function (key: string) {
      calls.push("get");
      const o = objects.get(key);
      if (!o) return null;
      return { ...meta(key, o), body: new Blob([o.body as BlobPart]).stream(), arrayBuffer: async () => o.body.buffer };
    },
    async head(key: string) {
      calls.push("head");
      const o = objects.get(key);
      return o ? meta(key, o) : null;
    },
    put: async function (key: string, value: string | ArrayBuffer | Uint8Array, opts: Partial<Stored> = {}) {
      calls.push("put");
      const body =
        typeof value === "string" ? new TextEncoder().encode(value) : value instanceof Uint8Array ? value : new Uint8Array(value);
      const o = { body, httpMetadata: opts.httpMetadata, customMetadata: opts.customMetadata };
      objects.set(key, o);
      return meta(key, o);
    },
    async delete(keys: string | string[]) {
      calls.push("delete");
      for (const k of Array.isArray(keys) ? keys : [keys]) objects.delete(k);
    },
  };
  return bucket;
}
