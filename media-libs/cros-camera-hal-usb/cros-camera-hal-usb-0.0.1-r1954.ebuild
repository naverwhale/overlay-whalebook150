# Copyright 2017 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
	"4775a5be81f113aa93a6867b9e5c2576fcab81e6"  # camera/build
	"9d5a2a0cdb9fce70bfb36ab315206c7927d44227"  # camera/common
	"ce58cd961aa5392c526f0fcd7628a79d7fd76c38"  # camera/hal/usb
	"824ea58991cc7bca28f57df8fedafdf7dec36a29"  # camera/include
	"0e7d4d4aac5fe2e42c89c6335278db4cd635aec2"  # camera/mojo
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
)
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_LOCALNAME="../platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
# TODO(crbug.com/809389): Avoid directly including headers from other packages.
CROS_WORKON_SUBTREE=".gn camera/build camera/common camera/hal/usb camera/include camera/mojo common-mk"
CROS_WORKON_INCREMENTAL_BUILD="1"

PLATFORM_SUBDIR="camera/hal/usb"

inherit cros-camera cros-workon platform

DESCRIPTION="Chrome OS USB camera HAL v3."

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"
IUSE="asan"

RDEPEND="
	chromeos-base/cros-camera-android-deps
	chromeos-base/cros-camera-libs
	dev-cpp/abseil-cpp:=
	dev-libs/re2:=
	media-libs/libsync
	virtual/jpeg:0="

DEPEND="${RDEPEND}
	media-libs/libyuv
	virtual/pkgconfig"

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-camera-hal-usb.patch"
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
