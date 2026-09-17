# Copyright 2012 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"16839d1d0fcecb39e52d1bc3a65aa02d62c1ee6d"  # chromeos-config
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"ac98ee20c01d66b5c797f69f5c6f49dc6b3b1557"  # installer
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"7f906bce285d1db058a8b829e73db7c00aa236f1"  # verity
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_INCREMENTAL_BUILD=1
# We don't use CROS_WORKON_OUTOFTREE_BUILD here since Cargo.toml is
# using the "provided by ebuild" macro supported by cros-rust.

# TODO(crbug.com/809389): Avoid directly including headers from other packages.
CROS_WORKON_SUBTREE="chromeos-config common-mk installer metrics verity .gn"

PLATFORM_SUBDIR="installer"
# Do not run test parallelly until unit tests are fixed.
# shellcheck disable=SC2034
PLATFORM_PARALLEL_GTEST_TEST="no"

inherit cros-unibuild cros-workon cros-rust platform systemd

DESCRIPTION="Chrome OS Installer"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/installer/"
SRC_URI=""

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"
IUSE="
	cros_embedded
	disable_lvm_install
	default_key_stateful
	enable_slow_boot_notify
	pam
	systemd
	lvm_stateful_partition
	postinstall_cgpt_repair
	postinstall_config_efi_and_legacy
	manage_efi_boot_entries
	postinst_metrics
"

COMMON_DEPEND="
	chromeos-base/chromeos-config-tools:=
	chromeos-base/vboot_reference:=
	chromeos-base/verity
	dev-cpp/abseil-cpp:=
	manage_efi_boot_entries? (
		sys-libs/efivar
	)
	postinst_metrics? ( chromeos-base/metrics )
	lvm_stateful_partition? ( chromeos-base/thinpool_migrator )
  dev-cpp/abseil-cpp
"

DEPEND="${COMMON_DEPEND}
	dev-rust/libchromeos:=
	dev-libs/openssl:0=
	dev-rust/third-party-crates-src:=
"

RDEPEND="${COMMON_DEPEND}
	pam? ( app-admin/sudo )
	chromeos-base/chromeos-common-script
	!cros_embedded? ( chromeos-base/chromeos-storage-info )
	dev-libs/openssl:0=
	dev-util/shflags
	sys-apps/rootdev
	sys-apps/util-linux
	sys-apps/which
	sys-fs/e2fsprogs"

src_unpack() {
	platform_src_unpack
	cros-rust_src_unpack
}

src_configure() {
	platform_src_configure
	cros-rust_src_configure
}

src_compile() {
	platform_src_compile
	cros-rust_src_compile \
		--package chromeos-install \
		--package install-copy-esp
}

platform_pkg_test() {
	platform_test "run" "${OUT}/cros_installer_test"
}

src_test() {
	platform_src_test
	cros-rust_src_test
}

src_install() {
	platform_src_install
	dosbin "$(cros-rust_get_build_dir)/chromeos-install"
	dosbin "$(cros-rust_get_build_dir)/install-copy-esp"

	# Install init scripts. Non-systemd case is defined in BUILD.gn.
	if use systemd; then
		systemd_dounit init/install-completed.service
		systemd_enable_service boot-services.target install-completed.service
		systemd_dounit init/crx-import.service
		systemd_enable_service system-services.target crx-import.service
	fi
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-installer.patch"
)

src_prepare() {
	local platform2_root="${S%/${PLATFORM_SUBDIR}}"
	pushd "${platform2_root}" > /dev/null || die
	local p; for p in "${WHALEOS_PATCHES[@]}"; do
		git apply --no-index -p1 "${p}" || die "git apply failed: ${p}"
	done
	popd > /dev/null || die
	cros-rust_src_prepare
}
