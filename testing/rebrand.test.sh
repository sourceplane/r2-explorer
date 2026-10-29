#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — the source link, the site-name seam, the worker name in the component
# and the wrangler config, the R2 bucket names and the terraform `repo` they
# are built from, the placeholder domain, a secret ref — and the
# survival cases run through three passes, so a value an earlier rebrand
# wrote (a re-run phase re-runs the rebrand over everything placed) comes
# out of every later one unchanged.
#
# The identity is PINNED (fixtures/baseline-identity.r2-explorer.json)
# rather than read from .baseline/identity.json: what this tests is the engine,
# and its fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.r2-explorer.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-uploads","productname":"Acme Uploads","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the site's own identity"
check "the source link names the product's owner and repository" \
  "$acme" README.md \
  'Source: https://github.com/sourceplane/r2-explorer' \
  'Source: https://github.com/acme-inc/acme-uploads'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/src/site.ts 'export const SITE_NAME = "My Files"' \
  'export const SITE_NAME = "Acme Uploads"'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-uploads","productname":"Sam'"'"'s Photos & Files","productdomain":"sam.dev"}' \
  apps/web/src/site.ts 'export const SITE_NAME = "My Files"' \
  'export const SITE_NAME = "Sam'"'"'s Photos & Files"'
check "the display name elsewhere is content, and is left alone" \
  "$acme" apps/web/README.md 'My Files, wherever it is not the seam, is prose.' \
  'My Files, wherever it is not the seam, is prose.'
check "the worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml 'workerName: r2-explorer-web' \
  'workerName: acme-uploads-web'
check "the wrangler config's worker name, template and render alike" \
  "$acme" apps/web/wrangler.template.jsonc '  "name": "r2-explorer-web",' \
  '  "name": "acme-uploads-web",'
check "the environment URLs: worker name and subdomain" \
  "$acme" intent.yaml '    url: https://r2-explorer-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://acme-uploads-web-stage.acme.workers.dev'
check "the R2 root's terraform repo — every bucket name is built on it" \
  "$acme" infra/terraform/cloudflare-r2/terraform/main.tf '  default = "r2-explorer"' \
  '  default = "acme-uploads"'
check "the per-environment terraform repo parameter" \
  "$acme" intent.yaml '        repo: r2-explorer' \
  '        repo: acme-uploads'
check "a fixture's bucket name follows the same rule" \
  "$acme" apps/web/wiring.fixture.json '  "cloudflare-r2/stage": { "r2_bucket_name": "stg-r2-explorer-stage" },' \
  '  "cloudflare-r2/stage": { "r2_bucket_name": "stg-acme-uploads-stage" },'
check "…and so does the committed render's binding" \
  "$acme" apps/web/wrangler.jsonc '      "bucket_name": "stg-r2-explorer-stage"' \
  '      "bucket_name": "stg-acme-uploads-stage"'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: r2-explorer.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-uploads","productname":"Acme Uploads","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: r2-explorer.example.com' \
  '      BASE_DOMAIN: acme-uploads.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-uploads","productname":"Acme Uploads","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: r2-explorer.example.com' \
  '      BASE_DOMAIN: acme-uploads.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "r2-explorer",' \
  '  "name": "acme-uploads",'
check "a wiring secret ref names the product's workspace and project" \
  "$acme" apps/web/component.yaml \
  '    WIRING_CLOUDFLARE_R2_STAGE: "secret://r2-explorer/r2-explorer/stage/WIRING_CLOUDFLARE_R2"' \
  '    WIRING_CLOUDFLARE_R2_STAGE: "secret://ws_79BDXAZQ/acme-uploads/stage/WIRING_CLOUDFLARE_R2"'
check "the R2 root's templated token ref too (the r2-data key, bound as the provider's token)" \
  "$acme" infra/terraform/cloudflare-r2/component.yaml \
  '    CLOUDFLARE_API_TOKEN: "secret://r2-explorer/r2-explorer/{{ .environment }}/CLOUDFLARE_R2_TOKEN"' \
  '    CLOUDFLARE_API_TOKEN: "secret://ws_79BDXAZQ/acme-uploads/{{ .environment }}/CLOUDFLARE_R2_TOKEN"'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg the source link keeps the baseline's owner" \
  '{"reponame":"acme-uploads","productname":"Acme Uploads","productdomain":"acme.dev"}' \
  README.md 'Source: https://github.com/sourceplane/r2-explorer' \
  'Source: https://github.com/sourceplane/acme-uploads'
check "the optional sign-in secrets name the product's workspace and project" \
  "$acme" apps/web/component.yaml \
  '    BASIC_AUTH_PASSWORD: "secret://r2-explorer/r2-explorer/{{ .environment }}/BASIC_AUTH_PASSWORD"' \
  '    BASIC_AUTH_PASSWORD: "secret://ws_79BDXAZQ/acme-uploads/{{ .environment }}/BASIC_AUTH_PASSWORD"'
check "the Worker the sign-in is pushed to is the product's" \
  "$acme" apps/web/component.yaml \
  '    buildCommand: node ../../tooling/wire/worker-secrets.mjs --secret BASIC_AUTH_USERNAME --worker "r2-explorer-web-${ORUN_ENVIRONMENT}" --config wrangler.jsonc' \
  '    buildCommand: node ../../tooling/wire/worker-secrets.mjs --secret BASIC_AUTH_USERNAME --worker "acme-uploads-web-${ORUN_ENVIRONMENT}" --config wrangler.jsonc'

# THE UPSTREAM PACKAGE'S NAME IS THIS BASELINE'S SLUG. `r2-explorer` on npm,
# whose `R2Explorer` export is the slug's own Pascal form: renamed, a product
# would depend on a package that does not exist. Every place the tree names
# the PACKAGE (tooling/rebrand/rebrand.mjs UPSTREAM) comes out unchanged —
# and the code identifier everywhere else is still residue (below).
echo "── rebrand: the upstream package keeps its name"
check "the pinned dependency" \
  "$acme" apps/web/package.json '    "r2-explorer": "1.1.10"' \
  '    "r2-explorer": "1.1.10"' 3
check "the one import, beside a renamed worker name" \
  "$acme" apps/web/src/index.ts 'import { R2Explorer as explorer } from "r2-explorer"; // r2-explorer-web' \
  'import { R2Explorer as explorer } from "r2-explorer"; // acme-uploads-web' 3
check "the build resolving the package" \
  "$acme" apps/web/scripts/build-dashboard.mjs 'require.resolve("r2-explorer/package.json")' \
  'require.resolve("r2-explorer/package.json")' 3
check "the package's directory" \
  "$acme" apps/web/README.md 'copied from node_modules/r2-explorer/dashboard' \
  'copied from node_modules/r2-explorer/dashboard' 3
check "its npm page and the template it was ported from" \
  "$acme" README.md 'https://www.npmjs.com/package/r2-explorer · https://github.com/cloudflare/templates/tree/main/r2-explorer-template' \
  'https://www.npmjs.com/package/r2-explorer · https://github.com/cloudflare/templates/tree/main/r2-explorer-template' 3
check "…and a product whose slug contains the baseline's keeps both" \
  '{"reponame":"r2-explorer-2","productname":"My Files 2","githuborg":"sourceplane"}' apps/web/package.json '    "r2-explorer": "1.1.10", "name": "r2-explorer"' \
  '    "r2-explorer": "1.1.10", "name": "r2-explorer-2"' 3

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"r2-explorer-2","productname":"My Files 2","productdomain":"r2-explorer.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "r2-explorer",' \
  '  "name": "r2-explorer-2",' 3
check "a worker name built on it survives three passes" \
  "$contains" apps/web/component.yaml 'workerName: r2-explorer-web' \
  'workerName: r2-explorer-2-web' 3
check "a bucket name built on it survives three passes" \
  "$contains" apps/web/wiring.fixture.json '"r2_bucket_name": "prod-r2-explorer-prod"' \
  '"r2_bucket_name": "prod-r2-explorer-2-prod"' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: r2-explorer.example.com' \
  'BASE_DOMAIN: r2-explorer.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" apps/web/component.yaml 'workersDevSubdomain: your-workers-subdomain' \
  'workersDevSubdomain: your-workers-subdomain-2' 3
check "a site name containing the baseline's name survives three passes" \
  "$contains" apps/web/src/site.ts 'export const SITE_NAME = "My Files"' \
  'export const SITE_NAME = "My Files 2"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "r2-explorer-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "r2-explorer-2"' fail
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "r2-explorer"' fail --values
verify "a leftover worker name fails" \
  "$acme" apps/web/wrangler.jsonc '"name": "r2-explorer-web",' fail --values
verify "a leftover bucket name fails" \
  "$acme" apps/web/wiring.fixture.json '"r2_bucket_name": "stg-r2-explorer-stage"' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/app/x.ts 'export class R2Explorer {}' fail --values
verify "the package's import is not residue" \
  "$acme" apps/web/src/index.ts 'import { R2Explorer as explorer } from "r2-explorer";' pass --values
verify "…but the identifier anywhere else is" \
  "$acme" apps/web/src/index.ts 'const app = R2Explorer({});' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-uploads"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "R2_EXPLORER_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
