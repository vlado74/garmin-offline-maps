#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
    echo "!! worktree is dirty; commit or stash first" >&2
    git status --short >&2
    exit 1
fi

pass=0
fail=0
ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

make test >/dev/null 2>&1 && ok "test suite" || bad "test suite"
make lint >/dev/null 2>&1 && ok "Python lint"

make raster-demo >/dev/null 2>&1
if git diff --exit-code --quiet -- mapdata/raster-demo source/generated/RasterMapIndex.mc; then
    ok "synthetic raster pack is reproducible"
else
    bad "synthetic raster pack drifted"
    git checkout -- mapdata/raster-demo source/generated/RasterMapIndex.mc
fi

build_out="$(make build 2>&1)"
case "$build_out" in
    *"BUILD SUCCESSFUL"*) ok "fr265s PRG" ;;
    *) bad "fr265s PRG" ;;
esac
case "$build_out" in
    *WARNING*|*ERROR*) bad "warning-free build" ;;
    *) ok "warning-free build" ;;
esac

package_out="$(make package 2>&1)"
case "$package_out" in
    *"BUILD SUCCESSFUL"*) ok "Connect IQ package" ;;
    *) bad "Connect IQ package" ;;
esac

printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = "0" ] && [ -z "$(git status --porcelain)" ]
