#!/bin/sh
# Prune the built Cryptodome package tree (modules/cryptodome) down to the
# wyng import closure.
#
# Like modules/cpython-prune.sh this is a script, not an inline recipe, because
# the cryptodome recipe is printf'd into a generated Makefile: there the `$`
# escaping has to survive two make expansion layers plus a sub-make, and a
# miscount silently turns `${rel#./}` into a make variable reference (which
# expands to empty) instead of a shell parameter expansion.  Keeping the loop
# in a script removes make from the picture entirely.
#
# Usage: cryptodome-prune.sh <package-dir> <keep-file>
#   package-dir  the built lib/Cryptodome tree
#   keep-file    config/cryptodome-keep.txt (paths relative to package-dir)
#
# The keep file is a closed allowlist; a missing/empty file skips pruning so a
# bad checkout can never wipe the package.
set -eu

pkg=$1
keep=$2

[ -s "$keep" ] || exit 0
[ -d "$pkg" ] || exit 0

cd "$pkg"
find . -type f | while IFS= read -r rel; do
	rel=${rel#./}
	grep -qxF "$rel" "$keep" || rm -f "$rel"
done
find . -type d -empty -delete
