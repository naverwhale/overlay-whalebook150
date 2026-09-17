# Copyright 2024 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

# This ebuild only cares about its own FILESDIR and ebuild file, so it tracks
# the canonical empty project.
CROS_WORKON_PROJECT="chromiumos/infra/build/empty-project"
CROS_WORKON_LOCALNAME="../platform/empty-project"

inherit cros-workon

KEYWORDS="~*"

DESCRIPTION="Camera HAL config files"

LICENSE="Apache-2.0"
SLOT="0"

src_install() {
	insinto /etc/camera
	doins "${FILESDIR}"/camera_characteristics.conf
}
