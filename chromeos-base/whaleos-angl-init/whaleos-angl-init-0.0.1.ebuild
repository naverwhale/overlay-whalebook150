# Copyright (c) 2024 The Whale OS Authors.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI="7"

CROS_WORKON_COMMIT="d2d95e8af89939f893b1443135497c1f5572aebc"
CROS_WORKON_TREE="776139a53bc86333de8672a51ed7879e75909ac9"
inherit cros-workon udev

CROS_WORKON_PROJECT="chromiumos/infra/build/empty-project"
CROS_WORKON_LOCALNAME="platform/empty-project"

DESCRIPTION="Hinge angle related files for WhaleOS"

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"
IUSE=""
RDEPEND=""
DEPEND="${RDEPEND}"

src_install() {
  insinto /etc/init
  doins ${FILESDIR}/whaleos-angl.conf

  exeinto /lib/udev
  doexe ${FILESDIR}/whaleos-angl-init.sh

  insinto /lib/udev/rules.d
  doins ${FILESDIR}/99-whaleos-angl.rules
}
