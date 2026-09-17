#!/bin/bash
# Copyright 2026 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Refresh the pinned CROS_WORKON_COMMIT / CROS_WORKON_TREE hashes inside
# waydroid-helper-X.Y.Z[-rN].ebuild after a new commit lands on the local
# platform2 fork (i.e. when waydroid_helper/ source changes).
#
# Usage:
#   cd src/platform2 && git commit ...   # commit the source change first
#   bash third_party/chromiumos-overlay/chromeos-base/waydroid-helper/files/uprev.sh
#
# The script looks up HEAD of the platform2 repo and rewrites the stable
# ebuild's hashes in place.

set -euo pipefail

# Locate the platform2 checkout.  Default to ../../../platform2 relative to
# this script, which is correct when running from a normal whaleos checkout.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
P2_DIR=${WAYDROID_HELPER_P2_DIR:-"${SCRIPT_DIR}/../../../../../platform2"}
# Pick the current stable ebuild by glob so this keeps working across
# revision bumps (waydroid-helper-0.0.1.ebuild -> ...-r1.ebuild -> ...).
# Exclude the live -9999 ebuild (that one is workon-only and has no
# pins to refresh).  If multiple stable ebuilds coexist, the
# highest-sorted one wins, which matches portage's own
# revision-selection order.
# `|| true` on the pipeline: under `set -euo pipefail`, `grep` returning
# 1 (no matches) on an empty ls would trip `pipefail` and abort the
# script here, before the `if [[ ! -f "${EBUILD}" ]]` message below
# gets a chance to run.  Swallow that here so the empty-glob case
# still reaches the friendlier error path.
EBUILD=${WAYDROID_HELPER_EBUILD:-$(ls -1 "${SCRIPT_DIR}"/../waydroid-helper-[0-9]*.ebuild 2>/dev/null \
	| grep -v -- '-9999\.ebuild$' | sort -V | tail -n1 || true)}

if [[ ! -d "${P2_DIR}/.git" ]]; then
	echo "ERROR: platform2 checkout not found at ${P2_DIR}" >&2
	echo "       Set WAYDROID_HELPER_P2_DIR to override." >&2
	exit 1
fi
if [[ ! -f "${EBUILD}" ]]; then
	echo "ERROR: ebuild not found at ${EBUILD}" >&2
	exit 1
fi

COMMIT=$(git -C "${P2_DIR}" rev-parse HEAD)
TREE_COMMON_MK=$(git -C "${P2_DIR}" rev-parse HEAD:common-mk)
TREE_WAYDROID_HELPER=$(git -C "${P2_DIR}" rev-parse HEAD:waydroid_helper)
TREE_GN=$(git -C "${P2_DIR}" rev-parse HEAD:.gn)

echo "platform2 HEAD          = ${COMMIT}"
echo "  common-mk subtree     = ${TREE_COMMON_MK}"
echo "  waydroid_helper subtree = ${TREE_WAYDROID_HELPER}"
echo "  .gn subtree           = ${TREE_GN}"

# In-place rewrite.  We deliberately match the comment-tagged lines so the
# tree hashes stay tied to their human-readable subtree label.
sed -i \
	-e "s|^CROS_WORKON_COMMIT=.*$|CROS_WORKON_COMMIT=\"${COMMIT}\"|" \
	-e "s|^\t\"[0-9a-f]\{40\}\"  # common-mk\$|\t\"${TREE_COMMON_MK}\"  # common-mk|" \
	-e "s|^\t\"[0-9a-f]\{40\}\"  # waydroid_helper\$|\t\"${TREE_WAYDROID_HELPER}\"  # waydroid_helper|" \
	-e "s|^\t\"[0-9a-f]\{40\}\"  # .gn\$|\t\"${TREE_GN}\"  # .gn|" \
	"${EBUILD}"

echo "Updated: ${EBUILD}"
