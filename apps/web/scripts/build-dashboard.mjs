#!/usr/bin/env node
// The build: R2-Explorer's dashboard — a prebuilt single-page app the npm
// package ships under `dashboard/` — copied into dist/dashboard, the Static
// Assets directory wrangler.jsonc names, with its <title> set to the
// product's name (src/site.ts). Nothing else in it changes.
//
// Upstream serves the package's directory in place
// (`node_modules/r2-explorer/dashboard`). A copy is what this monorepo needs:
// under pnpm that directory is a link into the store, and the composition's
// verify-build-output step checks the assets directory the build produced.
// Zero-dependency; the Worker itself (src/index.ts) is bundled by
// `wrangler deploy`.
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { siteNameOf, withTitle } from "./dashboard-title.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const app = path.resolve(here, "..");
const out = path.join(app, "dist", "dashboard");

// The package's own directory, resolved the way the Worker's import is.
const require = createRequire(path.join(app, "package.json"));
const pkg = path.dirname(require.resolve("r2-explorer/package.json"));
const source = path.join(pkg, "dashboard");
if (!fs.existsSync(path.join(source, "index.html"))) {
  console.error(`build-dashboard: no dashboard in ${source} — is the package installed?`);
  process.exit(1);
}

// The site name, read from the seam the rebrand writes.
let name;
try {
  name = siteNameOf(fs.readFileSync(path.join(app, "src", "site.ts"), "utf8"));
} catch (err) {
  console.error(`build-dashboard: ${err.message}`);
  process.exit(1);
}

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.cpSync(source, out, { recursive: true, dereference: true });

let titled = 0;
for (const rel of ["index.html", path.join("spa", "index.html")]) {
  const file = path.join(out, rel);
  if (!fs.existsSync(file)) continue;
  const next = withTitle(fs.readFileSync(file, "utf8"), name);
  if (next === null) {
    console.error(`build-dashboard: ${rel} has no <title> to set`);
    process.exit(1);
  }
  fs.writeFileSync(file, next);
  titled += 1;
}
const count = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).reduce((n, e) => n + (e.isDirectory() ? count(path.join(dir, e.name)) : 1), 0);
console.log(`build-dashboard: ${count(out)} file(s) → dist/dashboard, <title> ${JSON.stringify(name)} in ${titled} page(s)`);
