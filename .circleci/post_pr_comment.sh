#!/usr/bin/env bash
# Appends one row to a shared PR comment for this board's build.
# Called once per board from build_board after store_artifacts.
#
# Required env vars (set in CircleCI project settings or a context):
#   GITHUB_TOKEN   — GitHub token with pull-requests:write scope
#
# Provided automatically by CircleCI:
#   CIRCLE_PULL_REQUEST, CIRCLE_BUILD_URL,
#   CIRCLE_PROJECT_USERNAME, CIRCLE_PROJECT_REPONAME

set -euo pipefail

ARCH="$1"
TARGET="$2"
JSON="build/${ARCH}/${TARGET}/pr_artifacts.json"

[ -n "${CIRCLE_PULL_REQUEST:-}" ] || { echo "Not a PR build, skipping."; exit 0; }
[ -f "${JSON}" ]                  || { echo "No pr_artifacts.json found, skipping."; exit 0; }

: "${GITHUB_TOKEN:?GITHUB_TOKEN must be set}"

PR_NUMBER="${CIRCLE_PULL_REQUEST##*/}"
REPO="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
GITHUB_API="https://api.github.com"
export MARKER="<!-- heads-build-artifacts -->"

# Parse local pr_artifacts.json — no CircleCI API call needed
ROM_SHA=$(python3  -c "import json; print(json.load(open('${JSON}')).get('rom_sha256',''))")
ARCH_FILE=$(python3 -c "import json; print(json.load(open('${JSON}')).get('archive',''))")

SHORT_SHA="${ROM_SHA:0:16}..."
if [ -n "${ARCH_FILE}" ]; then
  DOWNLOAD="[${ARCH_FILE}](${CIRCLE_BUILD_URL})"
else
  DOWNLOAD="*(no archive)*"
fi
export NEW_ROW="| \`${TARGET}\` | \`${SHORT_SHA}\` | ${DOWNLOAD} |"

# Fetch existing PR comments
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT
COMMENTS="${TMPDIR}/comments.json"
curl -sf \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${GITHUB_API}/repos/${REPO}/issues/${PR_NUMBER}/comments?per_page=100" \
  > "${COMMENTS}"

# Find existing marker comment (if any)
COMMENT_ID=$(python3 -c "
import json, os
for c in json.load(open('${COMMENTS}')):
    if os.environ['MARKER'] in c.get('body', ''):
        print(c['id']); break
" 2>/dev/null) || COMMENT_ID=""

BODY_FILE="${TMPDIR}/body.txt"

if [ -n "${COMMENT_ID}" ]; then
  # Append this board's row to the existing comment
  python3 -c "
import json, os
for c in json.load(open('${COMMENTS}')):
    if os.environ['MARKER'] in c.get('body', ''):
        print(c['body'].rstrip() + '\n' + os.environ['NEW_ROW'])
        break
" > "${BODY_FILE}"
  curl -sf -X PATCH \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${GITHUB_API}/repos/${REPO}/issues/comments/${COMMENT_ID}" \
    -d "$(python3 -c "import json; print(json.dumps({'body': open('${BODY_FILE}').read()}))")" \
    > /dev/null
  echo "Appended row for ${TARGET} to comment ${COMMENT_ID}."
else
  # First board to finish: create the comment with header + first row
  printf '%s\n## CircleCI build artifacts\n\n| Board | ROM sha256 | Download |\n|-------|-----------|----------|\n%s\n' \
    "${MARKER}" "${NEW_ROW}" > "${BODY_FILE}"
  curl -sf -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${GITHUB_API}/repos/${REPO}/issues/${PR_NUMBER}/comments" \
    -d "$(python3 -c "import json; print(json.dumps({'body': open('${BODY_FILE}').read()}))")" \
    > /dev/null
  echo "Created comment with first row for ${TARGET}."
fi
