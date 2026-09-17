# Copyright 2026 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

# These two pins make this ebuild a stable release built from a known
# revision of our platform2 fork.  When the waydroid_helper/ source is
# updated, commit it and re-run scripts/uprev.sh (see README) to refresh
# the hashes below.
CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)

CROS_WORKON_INCREMENTAL_BUILD="1"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_SUBTREE="common-mk .gn"

PLATFORM_SUBDIR="waydroid_helper"

inherit cros-workon platform

DESCRIPTION="D-Bus helper proxying Chrome app management requests to the Waydroid CLI"
HOMEPAGE="https://github.com/whaleos"

# BSD needs copyright attribution, and CROS_WORKON_SUBTREE brings in no
# license file (platform2 keeps its LICENSE at the root), so the NAVER text
# ships as files/LICENSE.whaleos and src_unpack copies it to
# ${WORKDIR}/LICENSE.whaleos, where chromite's license scan finds it in any
# tree, including the public board overlay built against vanilla ChromiumOS.
# This overlay also carries the same text as
# licenses/copyright-attribution/chromeos-base/waydroid-helper, which
# chromite prefers when present; keep the two files identical.
LICENSE="BSD"
KEYWORDS="*"
IUSE=""

RDEPEND="
	app-arch/libarchive:=
	app-containers/waydroid
	dev-libs/protobuf:=
"
DEPEND="
	${RDEPEND}
	chromeos-base/system_api:=
"

BDEPEND="
	chromeos-base/chromeos-dbus-bindings
"

src_unpack() {
	platform_src_unpack
	mkdir -p "${S}" || die
	cp "${FILESDIR}/LICENSE.whaleos" "${WORKDIR}/LICENSE.whaleos" \
		|| die "failed to stage NAVER LICENSE"
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-waydroid_helper.patch"
)

src_prepare() {
	local platform2_root="${S%/${PLATFORM_SUBDIR}}"
	pushd "${platform2_root}" > /dev/null || die
	local p; for p in "${WHALEOS_PATCHES[@]}"; do
		git apply --no-index -p1 "${p}" || die "git apply failed: ${p}"
	done
	popd > /dev/null || die
	default
}
