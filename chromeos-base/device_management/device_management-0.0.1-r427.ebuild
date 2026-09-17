# Copyright 2023 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"41a12df837a393cabb15aa3e428efaf95b170a6f"  # device_management
	"0db4f46cc41a6aacb17f45d7e65efb35784fb310"  # libhwsec
	"b8c09b0737d26e92e8c1543f785a92a112de09cc"  # libhwsec-foundation
	"00e60203a732c85c12f77c0e13be1a50a6819c91"  # libstorage
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="common-mk device_management libhwsec libhwsec-foundation libstorage metrics .gn"

PLATFORM_SUBDIR="device_management"

inherit cros-workon platform cros-protobuf user

DESCRIPTION="Device Management service for ChromiumOS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/device_management/"
SRC_URI=""

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="test tpm tpm_dynamic tpm_insecure_fallback tpm2"

RDEPEND="
	chromeos-base/libhwsec:=[test?]
	chromeos-base/libhwsec-foundation:=
	chromeos-base/device_management-client:=
	chromeos-base/libstorage:=
	chromeos-base/metrics:=
	chromeos-base/minijail:=
	dev-libs/openssl:=
"

DEPEND="${RDEPEND}
	chromeos-base/system_api:=
"

BDEPEND="
	chromeos-base/chromeos-dbus-bindings
	chromeos-base/minijail
"

pkg_preinst() {
	enewuser "device_management"
	enewgroup "device_management"
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-device_management.patch"
	"${FILESDIR}/whaleos-libhwsec.patch"
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
