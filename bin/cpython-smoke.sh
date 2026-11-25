#!/bin/sh
# CPython runtime smoke/import-trace gate.
#
# Runs inside docker_repro/build environment with a staged tools.cpio or
# runtime tree.  Explicitly validates module-declared runtime requirements.
#
# Usage:
#   cpython-smoke.sh <python-bin>
# Environment:
#   CPYTHON_SMOKE_IMPORTS   space-separated imports to validate
#   CPYTHON_SMOKE_PYTHONPATH extra build-tree package paths
set -eu
py=$1
loader=${CPYTHON_SMOKE_LOADER:-}
libpath=${CPYTHON_SMOKE_LIBPATH:-}
smoke_pythonpath=${CPYTHON_SMOKE_PYTHONPATH:-}
[ -e "$py" ] || { echo "cpython-smoke: missing python: $py" >&2; exit 1; }
run_py() {
  if [ -n "$loader" ]; then
    PYTHONPATH="${smoke_pythonpath}${PYTHONPATH:+:$PYTHONPATH}"     "$loader" ${libpath:+--library-path "$libpath"} "$py" "$@"
  else
    PYTHONPATH="${smoke_pythonpath}${PYTHONPATH:+:$PYTHONPATH}" "$py" "$@"
  fi
}

# Base interpreter startup/import sanity.
run_py -c 'import sys,encodings,io,os; print(sys.version.split()[0])' >/dev/null

# Module-declared smoke imports are passed by modules/cpython as:
#   CPYTHON_SMOKE_IMPORTS="mod1 mod2"
# Fallback: no module imports declared; only base interpreter sanity runs.
imports=${CPYTHON_SMOKE_IMPORTS:-}

if [ -n "$imports" ]; then
  CPYTHON_SMOKE_IMPORTS="$imports" run_py - <<'PY'
import importlib, os
mods = [m for m in os.environ.get('CPYTHON_SMOKE_IMPORTS','').split() if m]
for m in mods:
    try:
        importlib.import_module(m)
    except Exception as e:
        raise SystemExit(f'MISSING:{m}:{e}')
print('SMOKE_OK', len(mods))
PY
fi
