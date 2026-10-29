#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      install with the lockfile the product ships, render the wrangler
#      fixture and check the committed config IS that render, typecheck,
#      lint, test, build. The landing's own PR runs `plan` alone (an
#      `orun/BASE-*` branch), so THIS is where a product those steps refuse
#      is caught: before the tag, not after a build has merged it;
#   2. the stage lane's own steps, rendered by `orun plan` in the product for
#      a pull request (the verify profile: the deploy profile has no dry run)
#      — `verify-app-structure` (which checks the wrangler config exists
#      BEFORE anything is built), `build-app` (the component's buildCommand:
#      the live wiring render, then the build), `verify-build-output` and
#      `deploy-dry-run` (`wrangler deploy --dry-run --name <reponame>-web-stage`).
#      They run IN THE TREE THE RUNNER STAGES for the job
#      (testing/lib/stage-job.py), with the dependency layout the pinned
#      composition produces, and with the stage wiring document in the job's
#      environment as the platform resolves it (the component's secretEnv) —
#      so the bucket name in the built config is asserted to be the
#      document's, not the fixture's;
#      The explorer's sign-in is planted in the job's environment too (its
#      optionalSecretEnv), and asserted to be in no file the build wrote;
#   3. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim — the check the real deploy ends
#      with — then everything the explorer promises (testing/lib/
#      explorer-flows.py), twice: with no sign-in stored, read-only as
#      upstream ships it — the dashboard named after the product, its app
#      routes and assets served, the API listing the one bucket, every change
#      refused; and with a sign-in (written to .dev.vars by the product's own
#      worker-secrets tool, as the deploy lane pushes it with `wrangler secret
#      bulk`) — every /api route asking for it, the smoke unchanged, and a
#      signed-in user uploading, listing, reading back and deleting a file.
#      wrangler dev provides the bucket locally, with nothing but the build.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare tokens, apply the bucket, deploy for real and probe
# workers.dev. The R2 root is verified to `terraform validate` (RX2) and its
# plan is part of every pull request's lanes; the apply needs an account.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). A few minutes: two installs and builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step — the ones the product's retired
# Checks workflow ran, run here at once on the whole tree. A product's pull
# requests verify through ci.yml's lanes (the dashboard built and the Worker
# dry-deployed per environment, the R2 root planned, the tests run by their
# own lane), which do not lint, so before a tag THIS is where that is held.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"
s01="$(git -C "$tree" rev-parse HEAD~1)"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# The landing's build is done; its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. the stage lane's steps, in the job's own tree ──────────────────────
echo "── the stage lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
# A pull request that changes the page: the lane `orun plan` gives it.
git -C "$tree" checkout -q -b e2e-pr
echo "<!-- a change to the explorer's component -->" >> "$tree/apps/web/README.md"
git -C "$tree" -c user.email=e2e@example.invalid -c user.name=e2e commit -qam "a pull request"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base main --head HEAD --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("verify-app-structure", "build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
PY
# The job's private tree, staged as orun stages it. The source checkout
# carries no build output (nothing was built in it), and its dependencies are
# what the pinned composition says: a lane-scoped install ran once in the
# source tree and is linked in, or the job installs its own.
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
[ -f "$scratch/steps/install.sh" ] || { echo "FAIL: the stage lane has no install step" >&2; exit 1; }
if [ "$(cat "$scratch/steps/install.scope")" = lane ]; then
  (cd "$tree" && bash -e "$scratch/steps/install.sh") > "$scratch/install.log" 2>&1 \
    || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
  echo "   ▸ install-workspace-dependencies"
  (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/install.wd")" && bash -e "$scratch/steps/install.sh") \
    > "$scratch/install.log" 2>&1 || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
    || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
fi
[ ! -e "$work/apps/web/dist" ] || { echo "FAIL: the staged tree carries build output" >&2; exit 1; }
[ ! -e "$work/apps/web/.dev.vars" ] || { echo "FAIL: the staged tree carries a .dev.vars" >&2; exit 1; }
# What the platform resolves into the job before its first step: the wiring
# documents the R2 root lease-published (the component's secretEnv), shaped as
# its `output "wiring"` is. Names no fixture carries, so the built config
# proves which one it was rendered from.
for env in stage prod; do
  key="WIRING_CLOUDFLARE_R2_$(echo "$env" | tr a-z A-Z)"
  grep -qx "$key" "$scratch/steps/secrets" || { echo "FAIL: the stage lane does not resolve $key" >&2; exit 1; }
done
# …and the explorer's sign-in, which the job resolves too when the product has
# stored it (optionalSecretEnv): markers no source carries, so a bundle or an
# asset that held either would be caught below.
for key in BASIC_AUTH_USERNAME BASIC_AUTH_PASSWORD; do
  grep -qx "$key" "$scratch/steps/secrets" || { echo "FAIL: the stage lane does not resolve the optional $key" >&2; exit 1; }
done
stage_bucket="stg-$repo-stage-5ca1ab1e"
export WIRING_CLOUDFLARE_R2_STAGE='{"r2_bucket_name":"'"$stage_bucket"'"}'
export WIRING_CLOUDFLARE_R2_PROD='{"r2_bucket_name":"prod-'"$repo"'-prod-5ca1ab1e"}'
user_marker="e2e-user-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
pass_marker="e2e-pass-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
export BASIC_AUTH_USERNAME="$user_marker" BASIC_AUTH_PASSWORD="$pass_marker"
for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`), its resolved secrets, and ORUN_ENVIRONMENT; the step runs in the
  # component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done
unset BASIC_AUTH_USERNAME BASIC_AUTH_PASSWORD
grep -q "\"bucket_name\": \"$stage_bucket\"" "$work/apps/web/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage bucket name from its wiring document" >&2; exit 1; }
grep -Eq "env\.bucket \($stage_bucket\) +R2 Bucket" "$scratch/deploy-dry-run.log" && grep -Eq "env\.ASSETS +Assets" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind the bucket to the stage bucket and ASSETS to the dashboard" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
# The sign-in reached the job and went nowhere a bundle or an asset could
# carry it: this lane holds no Cloudflare credential, so the secrets step
# says where it goes instead of pushing.
grep -q "BASIC_AUTH_USERNAME, BASIC_AUTH_PASSWORD reach $repo-web-stage from the deploy lane" "$scratch/build-app.log" \
  || { echo "FAIL: the build did not hand the sign-in on to the deploy lane's secrets step" >&2; grep "worker-secrets" "$scratch/build-app.log" >&2; exit 1; }
if grep -rlF -e "$user_marker" -e "$pass_marker" "$work/apps/web/dist" "$work/apps/web/wrangler.jsonc" 2>/dev/null | grep -q .; then
  echo "FAIL: the sign-in planted in the build's environment reached the build output" >&2; exit 1
fi
gz="$(grep -Eo 'Total Upload: [0-9.]+ KiB / gzip: [0-9.]+ KiB' "$scratch/deploy-dry-run.log" | grep -Eo '[0-9.]+ KiB$')"
echo "   the built config binds the bucket to the stage document's ($stage_bucket) and ASSETS to the"
echo "   dashboard; the sign-in is in no file the build wrote; the Worker is ${gz:-?} gzipped"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
serve() { # LOG — wrangler dev over the built Worker; sets $url and $dev_pid
  local log="$1" port
  port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
  (cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
     --name "$repo-web-stage" --persist-to "$scratch/state" --show-interactive-dev-session=false) > "$log" 2>&1 < /dev/null &
  dev_pid=$!
  url="http://127.0.0.1:$port"
  for _ in $(seq 1 90); do
    curl -s -o /dev/null "$url/api/health" && return 0
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$log" >&2; exit 1; }
    sleep 1
  done
  echo "FAIL: wrangler dev never answered" >&2; tail -30 "$log" >&2; exit 1
}
stop() {
  kill -TERM -- "-$dev_pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$dev_pid" 2>/dev/null || true
  dev_pid=""
}
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"

echo "── wrangler dev over the built Worker, no sign-in stored: read-only, as upstream ships it"
serve "$scratch/dev.log"
echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the explorer" >&2; exit 1; }
echo "   ▸ the dashboard, the API, and every change refused"
python3 "$here/lib/explorer-flows.py" read-only "$url" "$values" || exit 1
stop

echo "── …and with a sign-in, as the deploy lane hands it to the Worker (here as .dev.vars)"
# The product's own tool, in the mode a local run uses: the same two keys the
# deploy lane pushes with `wrangler secret bulk`, written where wrangler dev
# reads a Worker's secrets.
(cd "$work/apps/web" && BASIC_AUTH_USERNAME="sam" BASIC_AUTH_PASSWORD="correct horse" \
   node ../../tooling/wire/worker-secrets.mjs --secret BASIC_AUTH_USERNAME --secret BASIC_AUTH_PASSWORD --dev-vars .dev.vars) \
   > "$scratch/dev-vars.log" 2>&1 || { echo "FAIL: worker-secrets --dev-vars" >&2; cat "$scratch/dev-vars.log" >&2; exit 1; }
serve "$scratch/dev-signed-in.log"
echo "   ▸ the component's own smokeCommand, unchanged — the health route asks for no sign-in"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the signed-in explorer" >&2; exit 1; }
echo "   ▸ every /api route asks for the sign-in; signed in, a file uploaded, listed, read back and deleted"
python3 "$here/lib/explorer-flows.py" signed-in "$url" "$values" "sam" "correct horse" || exit 1
stop
rm -f "$work/apps/web/.dev.vars"

echo "e2e.test.sh: ok"
