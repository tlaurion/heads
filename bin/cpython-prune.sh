#!/bin/sh
# Post-install prune for the target CPython (modules/cpython).
#
# This lives in a script rather than inline in the module's _target because the
# _target text is passed through $(MAKE) -C <dir> <target> in the module
# harness: after the module variable is expanded once, the recipe is re-scanned
# by make, which turns `$name` into the undefined make variable `$n` followed by
# the literal `ame`.  A shell script keeps every shell expansion (`$name`,
# `${name%.py}`, ...) away from make's variable layer.
#
# Usage: cpython-prune.sh <install-root> <config-dir> <strip>
#   install-root  DESTDIR used by `make install` (contains lib/python3.13)
#   config-dir    directory holding cpython-stdlib-keep.txt /
#                 cpython-dynload-keep.txt
#   strip         cross `strip` command
#
# The two allowlists are closed keep lists: a missing/empty file skips the
# corresponding prune (never wipes the stdlib); anything not listed is removed.
set -eu

inst=$1
cfg=$2
strip=$3
py="$inst/lib/python3.13"

[ -d "$py" ] || exit 0

# Strip the dynload .so files: they are staged through _data into data.cpio,
# which the initrd strip helpers do not cover.
find "$py" -name '*.so' -exec "$strip" --strip-unneeded {} + 2>/dev/null || true

# Known-dead extras, then bytecode caches (build tree and vendored copies).
for dead in test idlelib tkinter turtledemo pydoc_data ensurepip venv lib2to3; do
	rm -rf "$py/$dead"
done
rm -rf "$py"/config-3.13-* 2>/dev/null || true
find "$py" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
find "$py" -type f -name '*.pyc' -exec rm -f {} + 2>/dev/null || true

# Top-level stdlib allowlist.  lib-dynload is governed by its own list below and
# site-packages holds the cryptodome/zstd extensions (always kept).
if [ -s "$cfg/cpython-stdlib-keep.txt" ]; then
	for entry in "$py"/*; do
		name=$(basename "$entry")
		name=${name%.py}
		case "$name" in lib-dynload | site-packages) continue ;; esac
		# Failsafe core set: never prune these even if the allowlist is
		# edited or replaced.  Build tooling (setuptools' vendored
		# distutils, and setup.py's `from __future__ import ...`) needs
		# them at import time; without this a single allowlist typo
		# removes the interpreter's own import machinery and breaks the
		# build in a hard-to-diagnose way (see __future__ regression).
		# `_sysconfigdata_*` is arch-specific and generated at install
		# time, so it is matched by glob rather than a fixed name.
		case "$name" in
			__future__ | os | io | abc | codecs | encodings | warnings | shlex | tomllib | _sysconfigdata_*) continue ;;
		esac
		grep -qxF "$name" "$cfg/cpython-stdlib-keep.txt" || rm -rf "$entry"
	done
fi

# lib-dynload allowlist (basename up to the first dot, dropping the ABI tag).
if [ -s "$cfg/cpython-dynload-keep.txt" ]; then
	for so in "$py"/lib-dynload/*.so; do
		name=$(basename "$so")
		name=${name%%.*}
		# Same failsafe idea as the stdlib sweep: `_opcode` backs the
		# `dis`/`opcode` import chain that setuptools' distutils shim
		# pulls in, and `_socket` is needed by http/email during builds.
		case "$name" in _opcode | _socket) continue ;; esac
		grep -qxF "$name" "$cfg/cpython-dynload-keep.txt" || rm -f "$so"
	done
fi
