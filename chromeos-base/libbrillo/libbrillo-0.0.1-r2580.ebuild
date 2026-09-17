# Copyright 2014 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"31e2627ffc07603eb3f4d9111f7bf63046898015"  # libbrillo
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="common-mk libbrillo .gn"

# b/445167625: Work around test failures.
CROS_SANITIZER_DISABLE_UBSAN_VPTR=1

PLATFORM_SUBDIR="libbrillo"

# platform.eclass automatically add dependency to libbrillo by default,
# but this package should not have the dependency.
WANT_LIBBRILLO="no"

# Do not run test parallelly until unit tests are fixed.
# shellcheck disable=SC2034
PLATFORM_PARALLEL_GTEST_TEST="no"

inherit cros-sanitizers cros-workon platform cros-protobuf

DESCRIPTION="Base library for Chromium OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/libbrillo/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="cros_host +dbus device-mapper enterprise_rollback_reven fuzzer udev usb"

COMMON_DEPEND="
	chromeos-base/minijail:=
	chromeos-base/perfetto:=
	>=chromeos-base/protofiles-0.0.75:=
	chromeos-base/vboot_reference:=
	dev-cpp/abseil-cpp:=
	dev-libs/openssl:=
	dev-libs/protobuf:=
	net-libs/grpc:=
	!cros_host? ( net-misc/curl:= )
	dbus? ( sys-apps/dbus:= )
	!cros_host? ( sys-apps/rootdev:= )
	sys-libs/zlib:=
	device-mapper? ( sys-fs/lvm2:=[thin] )
	udev? ( virtual/libudev )
	usb? ( virtual/libusb:1= )
"
RDEPEND="
	${COMMON_DEPEND}
	!cros_host? (
		chromeos-base/chromeos-ca-certificates
		chromeos-base/libchromeos-use-flags
	)
	!chromeos-base/libchromeos
"
DEPEND="
	${COMMON_DEPEND}
	dbus? ( chromeos-base/system_api:=[fuzzer?] )
	dev-libs/modp_b64:=
"

src_configure() {
	cros_optimize_package_for_speed
	platform_src_configure

	if use test; then
		# Do not check odr violations in address sanitizer.
		export ASAN_OPTIONS+=":detect_odr_violation=0:"
	fi
}
src_install() {
	platform_src_install

	# libbrillo library is created via an action script, install manually.
	dolib.so "${OUT}"/lib/libbrillo.so
	# Install libbrillo with and without version number as a temporary
	# measure.
	insinto "/usr/$(get_libdir)/pkgconfig"
	doins "${OUT}"/obj/libbrillo/libbrillo*.pc

	# Install all the header files from libbrillo/brillo/*.h into
	# /usr/include/brillo (recursively, with sub-directories).
	local dir
	while read -d $'\0' -r dir; do
		insinto "/usr/include/${dir}"
		doins "${dir}"/*.h
	done < <(find brillo -type d -print0)
	# Install all auto-generated proto_binding header files.
	insinto "/usr/include/brillo/proto_bindings"
	doins "${OUT}"/gen/include/brillo/proto_bindings/*.pb.h

	insinto /usr/include/policy
	doins policy/*.h
	insinto /usr/include/install_attributes
	doins install_attributes/libinstallattributes.h

	# fuzzer_component_id is unknown/unlisted
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/libbrillo_cryptohome_fuzzer
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/libbrillo_data_encoding_fuzzer
	platform_fuzzer_install "${S}"/OWNERS \
		"${OUT}"/libbrillo_dbus_data_serialization_fuzzer
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/libbrillo_http_form_data_fuzzer
	platform_fuzzer_install "${S}"/OWNERS \
		"${OUT}"/libbrillo_policy_device_policy_impl_fuzzer
}

platform_pkg_test() {
	local gtest_filter_qemu="-*DeathTest*"
	platform_test "run" "${OUT}/libbrillo_tests" "" "" "${gtest_filter_qemu}"
	platform_test "run" "${OUT}/libinstallattributes_tests"
	platform_test "run" "${OUT}/libpolicy_tests"
	platform_test "run" "${OUT}/libbrillo-grpc_tests"

	# `secure_blob_test_runner` does not work inside of qemu because of:
	# https://gitlab.com/qemu-project/qemu/-/issues/698
	# so do not run on different architectures.
	platform_is_native && (
		# Change the working directory so `secure_blob_test_runner` can find
		# `secure_blob_test_helper `.
		cd "${OUT}" || die
		platform_test "run" "${OUT}/secure_blob_test_runner"
	)
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-libbrillo.patch"
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
