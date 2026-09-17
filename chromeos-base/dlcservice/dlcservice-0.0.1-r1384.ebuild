# Copyright 2018 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"5f14740aa045a65cb4e1b813ef0657f5e03ecb3c"  # dlcservice
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
# TODO(crbug.com/809389): Avoid #include-ing platform2 headers directly.
CROS_WORKON_SUBTREE="common-mk dlcservice metrics .gn"

PLATFORM_SUBDIR="dlcservice"

inherit cros-workon platform cros-protobuf tmpfiles udev user

DESCRIPTION="A D-Bus service for Downloadable Content (DLC)"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/dlcservice/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="
	fuzzer
	lvm_stateful_partition
"

RDEPEND="
	chromeos-base/dlcservice-metadata:=
	chromeos-base/imageloader:=
	lvm_stateful_partition? ( chromeos-base/lvmd:= )
	chromeos-base/minijail:=
	>=chromeos-base/metrics-0.0.1-r3152:=
	chromeos-base/session_manager-client:=
	sys-apps/rootdev:=
	sys-libs/zlib:=
"

DEPEND="${RDEPEND}
	chromeos-base/dlcservice-client:=
	chromeos-base/imageloader-client:=
	lvm_stateful_partition? ( chromeos-base/lvmd-client:= )
	chromeos-base/system_api:=[fuzzer?]
	chromeos-base/update_engine-client:=
	chromeos-base/vboot_reference:=
"

BDEPEND="
	chromeos-base/chromeos-dbus-bindings
	chromeos-base/minijail
"

src_install() {
	platform_src_install

	# Install all the udev rules.
	udev_dorules "${FILESDIR}"/udev/*.rules

	# Tmpfiles.d configuration
	dotmpfiles tmpfiles.d/*.conf

	local fuzzer_component_id="908242"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/dlcservice_boot_device_fuzzer \
		--comp "${fuzzer_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/dlcservice_boot_slot_fuzzer \
		--comp "${fuzzer_component_id}"

	# Set up cryptohome daemon mount store.
	local daemon_store="/etc/daemon-store/dlcservice"
	dodir "${daemon_store}"
	fperms 0755 "${daemon_store}"
	fowners dlcservice:dlcservice "${daemon_store}"
}

platform_pkg_test() {
	platform_test "run" "${OUT}/dlcservice_tests"
}

pkg_setup() {
	# Has to be done in pkg_setup() instead of pkg_preinst() since
	# src_install() needs daemon user and daemon group.
	enewuser "dlcservice"
	enewgroup "dlcservice"
	enewgroup "disk-dlc" # For DLC logical volume management.
	cros-workon_pkg_setup
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-dlcservice.patch"
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
