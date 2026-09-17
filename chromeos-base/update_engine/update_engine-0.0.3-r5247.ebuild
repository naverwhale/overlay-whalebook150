# Copyright 2012 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"5f14740aa045a65cb4e1b813ef0657f5e03ecb3c"  # dlcservice
	"8f43dfd7edbac2a1aa65be54dfb9e8a923f456dd"  # libcrossystem
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"43eb4f30218ee6fc055f185786d914bccd668086"  # mojo_service_manager
	"be6d067909efa61c0c3db4a5a15e06c2cf20f0c2"  # oobe_config
	"ab116c69c86717bcba2b06665775c288089b1fdc"  # update_engine
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD=1

CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="common-mk dlcservice libcrossystem metrics mojo_service_manager oobe_config update_engine .gn"

# b/445168063: Work around test failures.
CROS_SANITIZER_DISABLE_UBSAN_VPTR=1

PLATFORM_SUBDIR="update_engine"
# Tests use /dev/loop*.
# shellcheck disable=SC2034
PLATFORM_HOST_DEV_TEST="yes"

inherit cros-sanitizers cros-debug cros-workon platform cros-protobuf systemd

DESCRIPTION="Chrome OS Update Engine"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/update_engine/"
SRC_URI=""

LICENSE="Apache-2.0"
KEYWORDS="*"
IUSE="cros_host cros_p2p dlc fuzzer hw_details -hwid_override lvm_stateful_partition minios +power_management systemd test"
RESTRICT="cros_host? ( test )"

# The bsdiff package installs static libs only, so we have to depend on its
# libs directly so we're rebuilt when their ABI changes too, even if we don't
# use the libs ourselves.
BSDIFF_DEPEND="
	app-arch/brotli:=
	app-arch/bzip2:=
	dev-util/bsdiff:=
	dev-libs/libdivsufsort:=
"

COMMON_DEPEND="
	${BSDIFF_DEPEND}
	app-arch/bzip2:=
	app-arch/zstd:=
	dlc? ( chromeos-base/dlcservice:= )
	hw_details? (
		chromeos-base/diagnostics:=
		chromeos-base/mojo_service_manager:=
	)
	cros_p2p? ( chromeos-base/p2p:= )
	dev-libs/openssl:=
	dev-libs/xz-embedded:=
	dev-util/puffin:=
	sys-fs/e2fsprogs:=
	!cros_host? (
		chromeos-base/chromeos-ca-certificates:=
		chromeos-base/chromeos-installer:=
		chromeos-base/imageloader:=
		>=chromeos-base/metrics-0.0.1-r3152:=
		chromeos-base/libcrossystem:=
		chromeos-base/oobe_config:=
		chromeos-base/runtime_hwid_utils:=
		chromeos-base/vboot_reference:=
		chromeos-base/vpd:=
		dev-libs/expat:=
		dev-libs/re2:=
		net-misc/curl:=
		sys-apps/rootdev:=
	)
"

CLIENT_DEPEND="
	chromeos-base/debugd-client:=
	dlc? ( chromeos-base/dlcservice-client:= )
	chromeos-base/imageloader-client:=
	chromeos-base/power_manager-client:=
	chromeos-base/session_manager-client:=
	chromeos-base/shill-client:=
	chromeos-base/update_engine-client:=
"

DEPEND="
	app-arch/xz-utils:=
	chromeos-base/system_api:=[fuzzer?]
	test? ( sys-fs/squashfs-tools )
	!cros_host? ( ${CLIENT_DEPEND} )
	${COMMON_DEPEND}
"

DELTA_GENERATOR_RDEPEND="
	app-arch/unzip:=
	app-arch/xz-utils:=
	|| (
		>=sys-fs/e2fsprogs-1.46.4-r5:=
		sys-libs/e2fsprogs-libs:=
	)
	sys-fs/squashfs-tools
"

RDEPEND="
	!cros_host? (
		virtual/update-policy:=
		${CLIENT_DEPEND}
	)
	${COMMON_DEPEND}
	cros_host? (
		${DEPEND}
		${DELTA_GENERATOR_RDEPEND}
	)
	power_management? ( chromeos-base/power_manager:= )
"

BDEPEND="
	chromeos-base/chromeos-dbus-bindings
"

platform_pkg_test() {
	local unittests_binary="${OUT}"/update_engine_unittests

	# The unittests will try to exec `./helpers`, so make sure we're in
	# the right dir to execute things.
	cd "${OUT}" || die
	# The tests also want keys to be in the current dir.
	# .pub.pem files are generated on the "gen" directory.
	cp "${S}"/unittest_key*.pem ./ || die
	cp gen/include/update_engine/unittest_key*.pub.pem ./ || die

	# The unit tests check to make sure the minor version value in
	# update_engine.conf match the constants in update engine, so we need to be
	# able to access this file.
	cp "${S}/update_engine.conf" ./

	# If GTEST_FILTER isn't provided, we run two subsets of tests
	# separately: the set of non-privileged  tests (run normally)
	# followed by the set of privileged tests (run as root).
	# Otherwise, we pass the GTEST_FILTER environment variable as
	# an argument and run all the tests as root; while this might
	# lead to tests running with excess privileges, it is necessary
	# in order to be able to run every test, including those that
	# need to be run with root privileges.
	if [[ -z "${GTEST_FILTER}" ]]; then
		platform_test "run" "${unittests_binary}" 0 '-*.RunAsRoot*'
		PLATFORM_PARALLEL_GTEST_TEST="no" \
			platform_test "run" "${unittests_binary}" 1 '*.RunAsRoot*'
	else
		PLATFORM_PARALLEL_GTEST_TEST="no" \
			platform_test "run" "${unittests_binary}" 1 "${GTEST_FILTER}"
	fi
}

src_install() {
	platform_src_install

	# Update payload should be verified with this public key in WhaleOS
	insinto /usr/share/update_engine
	if [ -f "${FILESDIR}"/update-payload-key.pub.pem ]; then
		doins "${FILESDIR}"/update-payload-key.pub.pem
	fi
	insinto /etc
	doins update_engine.conf

	if ! use cros_host; then
		if use systemd; then
			systemd_dounit "${FILESDIR}"/update-engine.service
			systemd_enable_service multi-user.target update-engine.service
		else
			# Install upstart script
			insinto /etc/init
			doins init/update-engine.conf
		fi

		# Install DBus configuration
		insinto /etc/dbus-1/system.d
		doins UpdateEngine.conf
	fi

	# TODO(b/182168271): Remove minios flag and public key from update_engine.
	# Add the public key only when signing for MiniOs.
	if use minios; then
		insinto "/build/initramfs"
		if [ -f "${FILESDIR}"/update-payload-key.pub.pem ]; then
			doins "${FILESDIR}"/update-payload-key.pub.pem
		fi
	fi

	local fuzzer_component_id="908319"
	platform_fuzzer_install "${S}"/OWNERS \
				"${OUT}"/update_engine_omaha_request_action_fuzzer \
				--dict "${S}"/fuzz/xml.dict \
				--comp "${fuzzer_component_id}"
	platform_fuzzer_install "${S}"/OWNERS \
				"${OUT}"/update_engine_delta_performer_fuzzer \
				--comp "${fuzzer_component_id}"
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-update_engine.patch"
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
