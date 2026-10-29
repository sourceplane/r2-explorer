#!/usr/bin/env python3
"""What the explorer promises, read off a served Worker (testing/e2e.test.sh).

  explorer-flows.py read-only <url> <values.json>
  explorer-flows.py signed-in <url> <values.json> <username> <password>

`read-only` is a product with no sign-in stored, as upstream ships it: the
dashboard (its <title> the product's name), the health route, the API's
server info and listing, every change refused, the single-page app's
fallback, the static assets, a 404. `signed-in` is the same Worker with
BASIC_AUTH_USERNAME and BASIC_AUTH_PASSWORD set: every /api route asks for
them (wrong ones refused), the health route still does not, and a signed-in
user uploads a file, lists it, reads it back byte for byte, makes a folder and
deletes both. Keys travel base64-encoded, as the dashboard sends them.
"""
import base64, html, json, re, sys, urllib.error, urllib.request
from urllib.parse import quote

mode, base, values = sys.argv[1], sys.argv[2], json.load(open(sys.argv[3]))
name = values["productname"]
problems = []
def bad(m): problems.append(m)

def req(path, method="GET", body=None, headers=None, auth=None):
    h = dict(headers or {})
    if auth:
        h["authorization"] = "Basic " + base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
    r = urllib.request.Request(base + path, data=body, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, resp.headers, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()

def j(b):
    try:
        return json.loads(b or b"null")
    except ValueError:
        return None

b64 = lambda s: base64.b64encode(s.encode("utf-8")).decode()

def health(want_mode):
    s, h, b = req("/api/health")
    body = j(b)
    if s != 200 or body != {"ok": True, "name": name, "bucket": "bucket", "mode": want_mode}:
        bad(f"/api/health answered {s} {b[:200]!r}, not ok/{name!r}/{want_mode}")
    if h.get("cache-control") != "no-store":
        bad(f"/api/health is cacheable ({h.get('cache-control')!r})")

def write_attempts(auth=None):
    """A folder and an upload, each with the given sign-in (or none)."""
    s1, _, b1 = req("/api/buckets/bucket/folder", "POST", json.dumps({"key": b64("e2e-folder")}).encode(),
                    {"content-type": "application/json"}, auth)
    s2, _, b2 = req(f"/api/buckets/bucket/upload?key={quote(b64('e2e.txt'))}", "POST", b"x",
                    {"content-type": "application/octet-stream"}, auth)
    return (s1, b1), (s2, b2)

if mode == "read-only":
    # The dashboard: upstream's single-page app from Static Assets, named.
    s, h, b = req("/")
    page = b.decode(errors="replace")
    title = re.search(r"<title>(.*?)</title>", page, re.S)
    if s != 200 or "id=q-app" not in page:
        bad(f"/ answered {s} without the dashboard's mount point")
    if not title or html.unescape(title.group(1)) != name:
        bad(f"the dashboard's <title> is {title and title.group(1)!r}, not {name!r}")
    if "My Files" in page or "<title>R2-Explorer" in page:
        bad("the dashboard still carries the baseline's or upstream's name as its title")
    s, h, b = req("/storage/bucket", headers={"sec-fetch-mode": "navigate", "accept": "text/html"})
    if s != 200 or "id=q-app" not in b.decode(errors="replace"):
        bad(f"a navigation to an app route answered {s} without the dashboard (single-page-application fallback)")
    for path, ctype in (("/favicon.ico", "image/"), ("/logo.png", "image/png")):
        s, h, b = req(path)
        if s != 200 or not (h.get("content-type") or "").startswith(ctype):
            bad(f"{path} answered {s} {h.get('content-type')}, want 200 {ctype}")
    s, _, _ = req("/no-such-file.js")
    if s != 404:
        bad(f"/no-such-file.js answered {s}, not 404")

    health("read-only")
    s, h, b = req("/api/server/config")
    info = j(b) or {}
    if s != 200 or (info.get("config") or {}).get("readonly") is not True or info.get("buckets") != [{"name": "bucket"}]:
        bad(f"/api/server/config answered {s} {b[:200]!r} — not a read-only explorer over the one bucket")
    if "auth" in info:
        bad(f"a read-only explorer reports a sign-in: {info.get('auth')}")
    s, h, b = req("/api/buckets/bucket?limit=10")
    if s != 200 or not isinstance((j(b) or {}).get("objects"), list):
        bad(f"listing the bucket answered {s} {b[:200]!r}")
    (s1, b1), (s2, b2) = write_attempts()
    for what, s, b in (("making a folder", s1, b1), ("uploading", s2, b2)):
        if s != 401 or "ReadOnly" not in b.decode(errors="replace"):
            bad(f"{what} in read-only mode answered {s} {b[:160]!r}, not upstream's 401 ReadOnly refusal")
    s, _, b = req("/api/buckets/ASSETS?limit=1")
    if s < 400:
        bad(f"/api/buckets/ASSETS answered {s}: a binding that is not a bucket must not list")
    summary = ("the dashboard (named, its app routes and assets served, a 404), /api/health read-only, the "
               "explorer over the one bucket, a folder and an upload refused")

elif mode == "signed-in":
    user, password = sys.argv[4], sys.argv[5]
    me = (user, password)
    health("read-write")
    for auth, label in ((None, "no sign-in"), ((user, "wrong"), "a wrong password"), (("someone", password), "a wrong user")):
        s, _, b = req("/api/server/config", auth=auth)
        if s != 401:
            bad(f"/api/server/config with {label} answered {s}, not 401")
    (s1, _), (s2, _) = write_attempts()
    if s1 != 401 or s2 != 401:
        bad(f"changes with no sign-in answered {s1} and {s2}, not 401")
    s, _, b = req("/api/server/config", auth=me)
    info = j(b) or {}
    if s != 200 or (info.get("config") or {}).get("readonly") is not False:
        bad(f"/api/server/config signed in answered {s} {b[:200]!r} — not a writable explorer")
    if info.get("auth") != {"type": "basic-auth", "username": user}:
        bad(f"the explorer reports the sign-in as {info.get('auth')}")
    if password in b.decode(errors="replace"):
        bad("the explorer echoes the password it was configured with")

    key, data = "e2e/Sam's notes & files.txt", "hello from the e2e — ünïcode included\n".encode()
    meta = b64(json.dumps({"contentType": "text/plain"}))
    s, _, b = req(f"/api/buckets/bucket/upload?key={quote(b64(key))}&httpMetadata={quote(meta)}", "POST", data,
                  {"content-type": "application/octet-stream"}, me)
    if s != 200:
        bad(f"uploading {key!r} answered {s} {b[:200]!r}")
    s, _, b = req(f"/api/buckets/bucket?limit=100&prefix={quote(b64('e2e/'))}", auth=me)
    listed = {o.get("key"): o.get("size") for o in (j(b) or {}).get("objects") or []}
    if listed.get(key) != len(data):
        bad(f"the listing under e2e/ is {listed}, not {key!r} of {len(data)} bytes")
    s, h, b = req(f"/api/buckets/bucket/{quote(b64(key), safe='')}", auth=me)
    if s != 200 or b != data:
        bad(f"reading {key!r} back answered {s} with {len(b)} bytes, not the {len(data)} uploaded")
    if (h.get("content-type") or "") != "text/plain" or "attachment" not in (h.get("content-disposition") or ""):
        bad(f"reading {key!r} back answered content-type {h.get('content-type')!r}, disposition {h.get('content-disposition')!r}")
    s, _, b = req("/api/buckets/bucket/folder", "POST", json.dumps({"key": b64("e2e/reports")}).encode(),
                  {"content-type": "application/json"}, me)
    if s != 200:
        bad(f"making a folder signed in answered {s} {b[:160]!r}")
    for k in (key, "e2e/reports/"):
        s, _, b = req("/api/buckets/bucket/delete", "POST", json.dumps({"key": b64(k)}).encode(),
                      {"content-type": "application/json"}, me)
        if s != 200 or (j(b) or {}).get("success") is not True:
            bad(f"deleting {k!r} answered {s} {b[:160]!r}")
    s, _, b = req(f"/api/buckets/bucket?limit=100&prefix={quote(b64('e2e/'))}", auth=me)
    left = [o.get("key") for o in (j(b) or {}).get("objects") or []]
    if left:
        bad(f"after deleting, e2e/ still lists {left}")
    summary = ("every /api route asks for the sign-in (none, a wrong password and a wrong user refused); signed in, a "
               "file uploaded, listed, read back byte for byte, a folder made, both deleted; /api/health read-write")
else:
    sys.exit(f"unknown mode {mode!r}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   {summary}")
