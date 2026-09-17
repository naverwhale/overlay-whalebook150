# Copyright 2020 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"b8c09b0737d26e92e8c1543f785a92a112de09cc"  # libhwsec-foundation
	"00e60203a732c85c12f77c0e13be1a50a6819c91"  # libstorage
	"8f43dfd7edbac2a1aa65be54dfb9e8a923f456dd"  # libcrossystem
	"abfde9e280085e12ed0ef4ebd34b1eeb4eab376a"  # minios
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="common-mk metrics libhwsec-foundation libstorage libcrossystem minios .gn"

PLATFORM_SUBDIR="minios"

inherit cros-workon platform cros-protobuf user

DESCRIPTION="The miniOS main logic."
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/minios/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="lvm_stateful_partition minios"
REQUIRED_USE="minios"

COMMON_DEPEND="
	acct-group/minios:=
	acct-user/minios:=
	chromeos-base/metrics:=
	chromeos-base/shill-client:=
	chromeos-base/update_engine-client:=
	chromeos-base/libcrossystem:=
	chromeos-base/libhwsec-foundation:=
	chromeos-base/libstorage:=
	chromeos-base/vpd:=
	dev-libs/protobuf
	sys-apps/util-linux:=
	x11-libs/libxkbcommon:=
	x11-misc/xkeyboard-config:=
"

RDEPEND="${COMMON_DEPEND}"
DEPEND="${COMMON_DEPEND}
	chromeos-base/chromeos-dbus-bindings:=
	chromeos-base/system_api:=
	chromeos-base/vboot_reference:=
"
BDEPEND="
	chromeos-base/chromeos-dbus-bindings
	chromeos-base/minijail
"

platform_pkg_test() {
	platform_test "run" "${OUT}/minios_test"
}

src_install() {
	platform_src_install

	into "/build/initramfs"
	dobin "${OUT}/minios"
	dobin "${OUT}/minios_client"
	dobin "${OUT}/minios_util"
	dobin scripts/root_partition_for_recovery
	dobin scripts/stateful_partition_for_recovery

	if use lvm_stateful_partition; then
		# shellcheck disable=SC2016
		# Replace lvm_stateful flag in stateful_partition_for_recovery to true.
		sed -i \
			'/DEFINE_boolean lvm_stateful "/s:\${FLAGS_FALSE}:\${FLAGS_TRUE}:' \
			"${D}/build/initramfs/bin/stateful_partition_for_recovery" ||
			die "Failed to set lvm_stateful in stateful_partition_for_recovery"
	fi

	# D-Bus configuration
	insinto "/build/initramfs/etc/dbus-1/system.d"
	doins org.chromium.MiniOs.conf
	insinto "/build/initramfs/"
	doins -r ramfs/*
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-minios.patch"
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
