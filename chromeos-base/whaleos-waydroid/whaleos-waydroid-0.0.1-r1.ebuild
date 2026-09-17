# Copyright 2026 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=7

DESCRIPTION="WhaleOS-specific Waydroid integration and helper scripts"
HOMEPAGE="https://whale.naver.com"

# BSD needs copyright attribution, and this package has no source archive
# (S is the empty WORKDIR), so the NAVER text ships as files/LICENSE.whaleos
# and src_unpack copies it to ${WORKDIR}/LICENSE.whaleos, where chromite's
# license scan finds it in any tree, including the public board overlay
# built against vanilla ChromiumOS.  It has to be src_unpack, not
# src_prepare: when license.json is missing from the vdb,
# `licenses --generate-licenses` (run by build_image) only runs
# `ebuild ... unpack` before scanning the work dir.  chromiumos-overlay also
# carries the same text as
# licenses/copyright-attribution/chromeos-base/whaleos-waydroid, which
# chromite prefers when present; keep the two files identical.
LICENSE="BSD"
SLOT="0"
KEYWORDS="-* amd64"
IUSE=""
S="${WORKDIR}"

RDEPEND="
	app-containers/waydroid
	chromeos-base/waydroid-helper
"
DEPEND=""

src_unpack() {
	default
	cp "${FILESDIR}/LICENSE.whaleos" "${WORKDIR}/LICENSE.whaleos" \
		|| die "failed to stage NAVER LICENSE"
}

src_install() {
	# WhaleOS-specific session starter script.
	# Sets WAYLAND_DISPLAY and XDG_RUNTIME_DIR to point to
	# the ChromeOS Exo compositor socket at /run/chrome/wayland-0.
	exeinto /usr/bin
	doexe "${FILESDIR}/waydroid-session"

	# udev rule to set permissions on DRI render nodes for waydroid LXC.
	insinto /lib/udev/rules.d
	doins "${FILESDIR}/60-waydroid-dri.rules"
}
