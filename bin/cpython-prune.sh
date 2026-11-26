#!/bin/sh
# Post-install prune + runtime staging for target CPython (modules/cpython).
#
# This script makes CPython inclusion explicit:
#   - INSTALL ($inst) keeps a build-required stdlib superset so dependent
#     modules (cryptodome/python-zstd/setuptools builds) can import Python
#     stdlib during their own build steps.
#   - RUNTIME ($runtime) is a separately pruned tree staged into tools.cpio.
#     It contains only the merged profile/runtime allowlist plus an explicit
#     minimal failsafe needed by the interpreter itself.
#
# Reasoning is encoded in data files, not hidden conditionals:
#   $cfg/cpython-stdlib-keep.txt                 merged runtime stdlib allowlist
#   $cfg/cpython-dynload-keep.txt                merged runtime dynload allowlist
#   $build_cfg/runtime-required-encodings.txt  minimal runtime codecs
#   build_req_stdlib/build_req_dynload: module-owned build requirements,
#   generated per-board by modules/cpython from <mod>_cpython_build_required_*.
#
# Keep-list format: one entry per line; blank lines and # comments ignored;
# inline ` # ...` comments stripped.
#
# Usage:
#   cpython-prune.sh <install-root> <profile-out-dir> <build-cfg-dir> <strip> <py-mm> <runtime-lib-dir> [build-stdlib-file] [build-dynload-file] [runtime-encodings-file] [source-root]
set -eu

inst=$1
cfg=$2
build_cfg=$3
strip=$4
py_mm=${5:-3.13}
if [ -z "$inst" ] || [ "$inst" = / ]; then
	echo "cpython-prune: install root must be a non-root directory" >&2
	exit 1
fi
runtime=${6:-$inst/lib/python$py_mm.runtime}
if [ -z "$runtime" ] || [ "$runtime" = / ]; then
	echo "cpython-prune: runtime must be a non-root directory" >&2
	exit 1
fi
build_req_stdlib=${7:-$build_cfg/build-required-stdlib.txt}
build_req_dynload=${8:-$build_cfg/build-required-dynload.txt}
runtime_encodings_file=${9:-$build_cfg/runtime-required-encodings.txt}
source_root=${10:-$(pwd)}

py="$inst/lib/python$py_mm"
[ -d "$py" ] || {
	echo "cpython-prune: missing CPython install tree: $py" >&2
	exit 1
}
# Validate the strip tool once, up front, so a bad $(CROSS)strip cannot yield a
# silently unstripped payload via the `|| true` on the find loops below. Resolve
# PATH names via command -v, but test -x explicitly: dash's `command -v` accepts
# a path that merely exists even when it is not executable.
strip_path=$(command -v "$strip" 2>/dev/null) || strip_path=""
if [ -z "$strip_path" ] || [ ! -x "$strip_path" ]; then
	echo "cpython-prune: strip is not executable: $strip" >&2
	exit 1
fi

normalize_keep() {
	# Emit normalized keep entries: strip CR, comments, blank lines.
	sed -e 's/\r$//' -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' -e '/^#/d' "$1"
}

in_keep() {
	# $1=name $2=keepfile
	normalize_keep "$2" | grep -qxF "$1"
}

in_any_keep() {
	# $1=name, remaining args=keepfiles
	name=$1; shift
	for keep_file in "$@"; do
		in_keep "$name" "$keep_file" && return 0
	done
	return 1
}

# Strip dynload .so files in INSTALL and any previous runtime tree.
find "$py" -name '*.so' -exec "$strip" --strip-unneeded {} + 2>/dev/null || true
if [ -d "$runtime" ]; then
	find "$runtime" -name '*.so' -exec "$strip" --strip-unneeded {} + 2>/dev/null || true
fi

# Known-dead extras, then bytecode caches.
for dead in test idlelib tkinter turtledemo pydoc_data ensurepip venv lib2to3; do
	rm -rf "${py:?}/$dead" "${runtime:?}/$dead"
done
rm -rf "$py"/config-"$py_mm"-* "$runtime"/config-"$py_mm"-* 2>/dev/null || true
find "$py" "$runtime" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
find "$py" "$runtime" -type f -name '*.pyc' -exec rm -f {} + 2>/dev/null || true

# Keep-lists are closed allowlists. Missing files are an error; an existing
# empty file is valid and means "keep no optional entries".
for keep_file in \
	"$build_req_stdlib" "$build_req_dynload" \
	"$cfg/cpython-stdlib-keep.txt" "$cfg/cpython-dynload-keep.txt"; do
	[ -f "$keep_file" ] || {
		echo "cpython-prune: missing keep-list: $keep_file" >&2
		exit 1
	}
done

# INSTALL tree: keep build-required superset. This intentionally keeps more
# than runtime so later module builds (cryptodome/python-zstd) can import
# Python stdlib they need. It is never staged into tools.cpio.
for entry in "$py"/*; do
	name=$(basename "$entry")
	name=${name%.py}
	case "$name" in lib-dynload | site-packages) continue ;; esac
	# Absolute interpreter/build failsafe. Keep this tiny and explicit.
	case "$name" in
		__future__ | _collections_abc | _sitebuiltins | _sysconfigdata_* | _weakrefset | abc | codecs | collections | encodings | genericpath | io | os | posixpath | site | stat | sysconfig | types | warnings ) continue ;;
	esac
	in_any_keep "$name" "$build_req_stdlib" "$cfg/cpython-stdlib-keep.txt" || rm -rf "$entry"
done
for so in "$py"/lib-dynload/*.so; do
	[ -e "$so" ] || continue
	name=$(basename "$so")
	name=${name%%.*}
	in_any_keep "$name" "$build_req_dynload" "$cfg/cpython-dynload-keep.txt" || rm -f "$so"
done

# RUNTIME tree: copy INSTALL then prune to merged runtime profile allowlist.
# site-packages is copied as-is (extensions staged by other modules).
rm -rf "$runtime"
mkdir -p "$(dirname "$runtime")"
cp -a "$py" "$runtime"

# The generated sysconfig module embeds absolute compiler/build paths. Keep the
# INSTALL copy intact for extension builds, but normalize the shipped runtime
# copy so checkout paths cannot change archive hashes or leak into the image.
source_root_sed=$(printf '%s' "$source_root" | sed 's/[][\\.^$*&|]/\\&/g')
for sysconfig in "$runtime"/_sysconfigdata__*.py; do
	[ -e "$sysconfig" ] || continue
	sed -i "s|$source_root_sed|/heads|g" "$sysconfig"
done

for entry in "$runtime"/*; do
	name=$(basename "$entry")
	name=${name%.py}
	case "$name" in lib-dynload | site-packages) continue ;; esac
	# Runtime failsafe is deliberately minimal and explicit; every entry
	# must be justified by interpreter startup/import behavior.
	# _sysconfigdata_* is arch-generated; keep to avoid sysconfig import
	# failures when profile needs sysconfig.
	case "$name" in
		__future__ | _collections_abc | _sitebuiltins | _sysconfigdata_* | _weakrefset | abc | codecs | collections | encodings | genericpath | io | os | posixpath | site | stat | sysconfig | types | warnings ) continue ;;
	esac
	in_keep "$name" "$cfg/cpython-stdlib-keep.txt" || rm -rf "$entry"
done

for so in "$runtime"/lib-dynload/*.so; do
	[ -e "$so" ] || continue
	name=$(basename "$so")
	name=${name%%.*}
	in_keep "$name" "$cfg/cpython-dynload-keep.txt" || rm -f "$so"
done

# Encodings: profile keeps 'encodings' package but not every codec file.
# Selection is explicit and auditable:
#   1) $cfg/cpython-encodings-keep.txt (merged profile override), else
#   2) module-owned generated runtime-required-encodings.txt, else
#   3) tiny built-in failsafe (utf_8/ascii/latin_1/aliases/__init__).
enc_keep=""
if [ -s "$cfg/cpython-encodings-keep.txt" ]; then
	enc_keep="$cfg/cpython-encodings-keep.txt"
elif [ -s "$runtime_encodings_file" ]; then
	enc_keep="$runtime_encodings_file"
fi
if [ -d "$runtime/encodings" ]; then
	for f in "$runtime"/encodings/*.py; do
		[ -e "$f" ] || continue
		b=$(basename "$f")
		if [ -n "$enc_keep" ]; then
			in_keep "$b" "$enc_keep" || rm -f "$f"
		else
			case "$b" in
				__init__.py|aliases.py|utf_8.py|ascii.py|latin_1.py) continue ;;
			esac
			rm -f "$f"
		fi
	done
fi

# Final bytecode cleanup after pruning/copy.
find "$py" "$runtime" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
find "$py" "$runtime" -type f -name '*.pyc' -exec rm -f {} + 2>/dev/null || true
