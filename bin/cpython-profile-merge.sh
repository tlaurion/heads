#!/bin/sh
# Merge selected CPython profile files into effective board-local allowlists.
# Usage: cpython-profile-merge.sh <out-dir> <profile-dir> [profile-dir...]
# Each profile dir must contain: stdlib-keep.txt, dynload-keep.txt, setup.local.disabled
# Existing empty keep-lists mean "keep no optional entries"; missing files are
# still errors. setup.local.disabled must remain non-empty.
set -eu
[ $# -ge 1 ] || { echo "cpython-profile-merge: usage: $0 <out-dir> <profile-dir>..." >&2; exit 1; }
out=$1; shift
[ $# -ge 1 ] || { echo "cpython-profile-merge: at least one profile required" >&2; exit 1; }
mkdir -p "$out"

merge_union() {
  out_file=$1; shift
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    { gsub(/[[:space:]]+$/, "", $0) }
    !seen[$0]++ { print $0 }
  ' "$@" > "$out_file"
}

merge_disable_intersection() {
  out_file=$1; shift
  # Setup.local is a disable list: keep a module disabled only if every selected
  # profile disables it. Module/profile data owns enablement; no global force.
  if [ $# -eq 1 ]; then cp "$1" "$out_file"; return; fi
  tmp="$out_file.tmp.$$"
  : > "$tmp.all"
  n=0
  for f in "$@"; do
    n=$((n+1))
    awk '/^[[:space:]]*#/ || /^[[:space:]]*$/ || /^\*disabled\*$/ {next}
         {gsub(/[[:space:]]+$/, "", $0); print}' "$f" | awk '!seen[$0]++ {print}' > "$tmp.$n"
    cat "$tmp.$n" >> "$tmp.all"
  done
  {
    echo "# Merged CPython Setup.local disable list (intersection across profiles)."
    echo "# A name present in *every* selected profile remains disabled."
    echo "*disabled*"
    awk -v n="$n" '{c[$0]++} END{for(k in c) if(c[k]==n) print k}' "$tmp.all" | \
      awk 'NR==FNR{ok[$0]=1; next} ok[$0]{print; delete ok[$0]}' - "$tmp.1"
  } > "$out_file"
  rm -f "$tmp".* "$tmp.all"
}

stdlib_files=""
dynload_files=""
setup_files=""
for d in "$@"; do
  [ -d "$d" ] || { echo "cpython-profile-merge: missing profile dir $d" >&2; exit 1; }
  # setup.local.disabled is never optional and must carry at least the
  # *disabled* marker.
  [ -s "$d/setup.local.disabled" ] || { echo "cpython-profile-merge: missing $d/setup.local.disabled" >&2; exit 1; }
  for f in stdlib-keep.txt dynload-keep.txt; do
    [ -f "$d/$f" ] || { echo "cpython-profile-merge: missing $d/$f" >&2; exit 1; }
  done
  stdlib_files="$stdlib_files $d/stdlib-keep.txt"
  dynload_files="$dynload_files $d/dynload-keep.txt"
  setup_files="$setup_files $d/setup.local.disabled"
done
# shellcheck disable=SC2086
merge_union "$out/cpython-stdlib-keep.txt" $stdlib_files
# shellcheck disable=SC2086
merge_union "$out/cpython-dynload-keep.txt" $dynload_files
# shellcheck disable=SC2086
merge_disable_intersection "$out/cpython-Setup.local" $setup_files
