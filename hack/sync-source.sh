#!/usr/bin/env bash

set -euo pipefail

UPSTREAM_REPO="$1"
UPSTREAM_REF="$2"        # branch / tag / commit
DEST_DIR="$3"

if [[ -z "${UPSTREAM_REPO}" || -z "${UPSTREAM_REF}" || -z "${DEST_DIR}" ]]; then
  echo "Usage: fetch-upstream.sh <repo> <ref> <dest-dir>"
  exit 1
fi

TMP_DIR="$(mktemp -d)"

echo "==> Fetching upstream repo"
echo "    Repo: ${UPSTREAM_REPO}"
echo "    Ref : ${UPSTREAM_REF}"

git clone --no-checkout "${UPSTREAM_REPO}" "${TMP_DIR}"
git -C "${TMP_DIR}" checkout "${UPSTREAM_REF}"

echo "==> Syncing upstream content into ${DEST_DIR}"

rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

(
  cd "${TMP_DIR}" || exit 1
  tar cf - --exclude='.git' --exclude='.github' .
) | (
  cd "${DEST_DIR}" || exit 1
  tar xf -
)

rm -rf "${TMP_DIR}"

echo "==> Upstream fetch completed"