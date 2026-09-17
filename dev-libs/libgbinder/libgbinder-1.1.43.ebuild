# Copyright 2024 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit multilib-minimal

DESCRIPTION="GLib-based Android binder client library"
HOMEPAGE="https://github.com/mer-hybris/libgbinder"
SRC_URI="https://github.com/mer-hybris/libgbinder/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="*"
IUSE=""
RESTRICT="mirror"

RDEPEND="
	>=dev-libs/libglibutil-1.0.61
	dev-libs/glib:2=
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_compile() {
	emake -C "${S}" LIBDIR="$(get_libdir)"
}

src_install() {
	emake -C "${S}" LIBDIR="$(get_libdir)" DESTDIR="${D}" install-dev

	# Makefile installs the .pc file to /${LIBDIR}/pkgconfig/ but the
	# standard pkg-config search path is /usr/${LIBDIR}/pkgconfig/.
	local libdir="$(get_libdir)"
	if [[ -f "${D}/${libdir}/pkgconfig/libgbinder.pc" ]]; then
		insinto "/usr/${libdir}/pkgconfig"
		doins "${D}/${libdir}/pkgconfig/libgbinder.pc"
		rm "${D}/${libdir}/pkgconfig/libgbinder.pc"
	fi
}
