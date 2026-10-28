#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
module="$root/modules/mod-ale"
revision=bd74eae623ca63154d3eb49e1d187e872ef13370
url=https://github.com/azerothcore/mod-ale.git
if [ -e "$module" ]; then
  test -d "$module/.git" || { echo 'Existing path is not the expected ALE repository' >&2; exit 1; }
  test -z "$(git -C "$module" status --porcelain)" || { echo 'ALE has local changes; refusing to modify it' >&2; exit 1; }
  test "$(git -C "$module" remote get-url origin)" = "$url" || { echo 'Unexpected ALE origin' >&2; exit 1; }
  test "$(git -C "$module" rev-parse HEAD)" = "$revision" || { echo 'ALE revision differs; inspect it manually' >&2; exit 1; }
else
  mkdir -p "$root/modules"
  git clone --no-checkout "$url" "$module"
  git -C "$module" checkout --detach "$revision"
fi
printf 'ALE pinned and clean: %s\n' "$revision"
