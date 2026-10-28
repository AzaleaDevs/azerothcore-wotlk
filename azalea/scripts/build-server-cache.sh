#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
expected_branch=server
build_context=${AZALEA_BUILD_CONTEXT:-/home/azalea/docker/Warcraft/build-contexts/server}
build_target=${AZALEA_BUILD_TARGET:-build}
build_output=${AZALEA_BUILD_OUTPUT:-type=cacheonly}

branch=$(git -C "$root" branch --show-current)
revision=$(git -C "$root" rev-parse HEAD)
common_dir=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)

if [[ "$branch" != "$expected_branch" ]]; then
  printf 'Refusing to build branch %s; expected %s\n' "$branch" "$expected_branch" >&2
  exit 1
fi

if [[ -n "$(git -C "$root" status --porcelain)" ]]; then
  printf 'Refusing to build a dirty server worktree\n' >&2
  exit 1
fi

# Materialize and verify the pinned external module in the source worktree.
bash "$root/azalea/scripts/bootstrap-ale.sh"

mkdir -p -- "$(dirname -- "$build_context")"
new_context=0
if [[ ! -e "$build_context" ]]; then
  git clone --local --no-hardlinks --no-checkout "$common_dir" "$build_context"
  git -C "$build_context" remote rename origin azalea-source
  new_context=1
elif [[ ! -d "$build_context/.git" ]]; then
  printf 'Build context exists but is not an independent Git clone: %s\n' "$build_context" >&2
  exit 1
fi

source_url=$(git -C "$build_context" remote get-url azalea-source 2>/dev/null || true)
if [[ "$source_url" != "$common_dir" ]]; then
  printf 'Unexpected build-context source: %s\n' "$source_url" >&2
  exit 1
fi

if [[ "$new_context" -eq 0 ]] && \
  [[ -n "$(git -C "$build_context" status --porcelain --untracked-files=no)" ]]; then
  printf 'Refusing to update a dirty build context: %s\n' "$build_context" >&2
  exit 1
fi

git -C "$build_context" fetch --prune azalea-source \
  '+refs/heads/server:refs/remotes/azalea-source/server'
git -C "$build_context" checkout -B server refs/remotes/azalea-source/server

if [[ "$(git -C "$build_context" rev-parse HEAD)" != "$revision" ]]; then
  printf 'Build context does not match the server worktree revision\n' >&2
  exit 1
fi

bash "$build_context/azalea/scripts/bootstrap-ale.sh"
ale_revision=$(git -C "$build_context/modules/mod-ale" rev-parse HEAD)
if [[ "$ale_revision" != bd74eae623ca63154d3eb49e1d187e872ef13370 ]]; then
  printf 'Unexpected ALE revision: %s\n' "$ale_revision" >&2
  exit 1
fi

cachebust=${AZALEA_CACHEBUST:-$revision}
printf 'Building server %s with ALE %s\n' "$revision" "$ale_revision"
printf 'Independent build context: %s\n' "$build_context"
printf 'Build target: %s; output: %s; cachebust: %s\n' \
  "$build_target" "$build_output" "$cachebust"

docker buildx build \
  --progress=plain \
  --file "$build_context/apps/docker/Dockerfile" \
  --build-arg "CACHEBUST=$cachebust" \
  --target "$build_target" \
  --output "$build_output" \
  "$build_context"
