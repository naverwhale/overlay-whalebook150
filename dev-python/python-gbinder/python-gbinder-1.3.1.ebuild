# Copyright 2024 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_11 )
DISTUTILS_USE_SETUPTOOLS=bdepend
DISTUTILS_EXT=1

inherit distutils-r1

DESCRIPTION="Python bindings for libgbinder (Android binder IPC)"
HOMEPAGE="https://github.com/waydroid/gbinder-python"
SRC_URI="https://github.com/waydroid/gbinder-python/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/gbinder-python-${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="*"
IUSE=""
RESTRICT="mirror"

RDEPEND="
	>=dev-libs/libgbinder-1.1.43
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-python/cython[${PYTHON_USEDEP}]
	virtual/pkgconfig
"

python_prepare_all() {
	# setup.py hardcodes 'pkg-config' as a subprocess call; chromiumos
	# cross-compilation blocks that wrapper. Patch to use ${PKG_CONFIG}.
	sed -i \
		-e 's/import sys, subprocess/import sys, subprocess, os/' \
		-e "s|'pkg-config --cflags --libs {}'.format(package)|(os.environ.get('PKG_CONFIG','pkg-config') + ' --cflags --libs {}').format(package)|" \
		setup.py || die
	distutils-r1_python_prepare_all
}

src_configure() {
	tc-export PKG_CONFIG
}
