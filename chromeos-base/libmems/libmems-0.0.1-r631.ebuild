# Copyright 2019 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"16839d1d0fcecb39e52d1bc3a65aa02d62c1ee6d"  # chromeos-config
	"47c9d8a1ba175459aaf9f255c44f91df349864ab"  # libmems
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD="1"
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="common-mk chromeos-config libmems .gn"

PLATFORM_SUBDIR="libmems"

inherit cros-workon platform

DESCRIPTION="MEMS support library for Chromium OS."
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/libmems"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE=""

COMMON_DEPEND="
	chromeos-base/chromeos-config-tools:=
	chromeos-base/system_api:=
	dev-cpp/abseil-cpp:=
	net-libs/libiio:=
	virtual/libudev:=
"
RDEPEND="${COMMON_DEPEND}"
DEPEND="${COMMON_DEPEND}"

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-libmems.patch"
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
