# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"581dcc7d00cfed28430e5d4c88b43acee9f97050"  # attestation
	"dd2fad2176ff8c02ae553e5a695b908e2ca4fe71"  # chaps
	"8f43dfd7edbac2a1aa65be54dfb9e8a923f456dd"  # libcrossystem
	"0db4f46cc41a6aacb17f45d7e65efb35784fb310"  # libhwsec
	"b8c09b0737d26e92e8c1543f785a92a112de09cc"  # libhwsec-foundation
	"00e60203a732c85c12f77c0e13be1a50a6819c91"  # libstorage
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"6c758e6ee408412dc2833681b642c2d01bc2dab1"  # tpm_manager
	"f182925db23c77d96440e4dade69bf4225393f47"  # trunks
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
# TODO(crbug.com/809389): Avoid directly including headers from other packages.
CROS_WORKON_SUBTREE="common-mk attestation chaps libcrossystem libhwsec libhwsec-foundation libstorage metrics tpm_manager trunks .gn"

PLATFORM_SUBDIR="attestation"

inherit cros-workon libchrome platform cros-protobuf user

DESCRIPTION="Attestation service for Chromium OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/attestation/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="cr50_onboard generic_tpm2 profiling test ti50_onboard tpm tpm_dynamic tpm2 tpm2_simulator"

REQUIRED_USE="
	tpm_dynamic? ( tpm tpm2 )
	!tpm_dynamic? ( ?? ( tpm tpm2 ) )
"

RDEPEND="
	tpm? (
		app-crypt/trousers:=
	)
	tpm2? (
		chromeos-base/trunks:=
	)
	chromeos-base/chaps:=
	chromeos-base/libcrossystem:=
	chromeos-base/libhwsec:=[test?]
	chromeos-base/libhwsec-foundation:=
	chromeos-base/system_api:=[fuzzer?]
	>=chromeos-base/metrics-0.0.1-r3152:=
	chromeos-base/libstorage:=
	chromeos-base/minijail:=
	chromeos-base/shill-client:=
	chromeos-base/tpm_manager-client:=
	chromeos-base/attestation-client
	dev-libs/openssl:0=
	"

DEPEND="
	${RDEPEND}
	tpm2? (
		chromeos-base/trunks:=
		chromeos-base/chromeos-ec-headers:=
	)
	"

BDEPEND="
	chromeos-base/chromeos-dbus-bindings
	chromeos-base/minijail
"

pkg_preinst() {
	# Create user and group for attestation.
	enewuser "attestation"
	enewgroup "attestation"
	# Create group for /mnt/stateful_partition/unencrypted/preserve.
	enewgroup "preserve"
}

src_install() {
	platform_src_install

	insinto /usr/include/attestation/common
	doins common/attestation_interface.h
	doins "${OUT}"/gen/attestation/common/print_attestation_ca_proto.h
	doins "${OUT}"/gen/attestation/common/print_interface_proto.h
	doins "${OUT}"/gen/attestation/common/print_keystore_proto.h

	# Install the generated dbus-binding for fake pca agent.
	# It does no harm to install the header even for non-test image build.
	insinto /usr/include/attestation/pca-agent/dbus_adaptors
	doins "${OUT}"/gen/include/attestation/pca-agent/dbus_adaptors/org.chromium.PcaAgent.h

	# Allow specific syscalls for profiling.
	# TODO (b/242806964): Need a better approach for fixing up the seccomp policy
	# related issues (i.e. fix with a single function call)
	if use profiling; then
		echo -e "\n# Syscalls added for profiling case only.\nmkdir: 1\nftruncate: 1\n" >> \
		"${D}/usr/share/policy/attestationd-seccomp.policy"
		echo -e "\n# Syscalls added for profiling case only.\nmkdir: 1\nftruncate: 1\n" >> \
		"${D}/usr/share/policy/pca_agentd-seccomp.policy"
	fi
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-attestation.patch"
	"${FILESDIR}/whaleos-chaps.patch"
	"${FILESDIR}/whaleos-libhwsec.patch"
	"${FILESDIR}/whaleos-tpm_manager.patch"
	"${FILESDIR}/whaleos-trunks.patch"
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
