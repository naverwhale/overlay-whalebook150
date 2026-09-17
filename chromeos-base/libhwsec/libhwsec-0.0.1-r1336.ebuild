# Copyright 2019 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"8f43dfd7edbac2a1aa65be54dfb9e8a923f456dd"  # libcrossystem
	"0db4f46cc41a6aacb17f45d7e65efb35784fb310"  # libhwsec
	"b8c09b0737d26e92e8c1543f785a92a112de09cc"  # libhwsec-foundation
	"00e60203a732c85c12f77c0e13be1a50a6819c91"  # libstorage
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"6c758e6ee408412dc2833681b642c2d01bc2dab1"  # tpm_manager
	"4d77cacb8ffb00858ed6eb987f3d41176fbfffe3"  # tpm2-simulator
	"f182925db23c77d96440e4dade69bf4225393f47"  # trunks
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
PYTHON_COMPAT=( python3_11 )

CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="common-mk libcrossystem libhwsec libhwsec-foundation libstorage metrics tpm_manager tpm2-simulator trunks .gn"

PLATFORM_SUBDIR="libhwsec"

inherit python-any-r1 cros-workon platform cros-protobuf

DESCRIPTION="Crypto and utility functions used in TPM related daemons."
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/libhwsec/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="profiling test fuzzer tpm tpm2 tpm_dynamic cr50_onboard ti50_onboard"

COMMON_DEPEND="
	chromeos-base/chromeos-ec-headers:=
	chromeos-base/libbrillo:=[fuzzer?]
	chromeos-base/libcrossystem:=
	chromeos-base/libhwsec-foundation:=
	chromeos-base/libstorage:=
	chromeos-base/metrics:=
	chromeos-base/system_api:=
	chromeos-base/tpm_manager-client:=
	dev-cpp/abseil-cpp:=
	dev-libs/openssl:0=
	dev-libs/flatbuffers:=
	dev-libs/re2:=
	tpm2? (
		chromeos-base/pinweaver:=
		chromeos-base/trunks:=
	)
	tpm? ( app-crypt/trousers:= )
	fuzzer? (
		app-crypt/trousers:=
		chromeos-base/trunks:=
	)
	test? (
		app-crypt/trousers:=
		chromeos-base/pinweaver:=
		chromeos-base/trunks:=
		chromeos-base/tpm2-simulator:=[test]
	)
"

RDEPEND="${COMMON_DEPEND}"
DEPEND="${COMMON_DEPEND}"

# shellcheck disable=SC2016
BDEPEND="
	dev-libs/flatbuffers
	$(python_gen_any_dep '
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/flatbuffers[${PYTHON_USEDEP}]
	')
"

python_check_deps() {
	python_has_version -b "dev-python/flatbuffers[${PYTHON_USEDEP}]"
}

src_install() {
	platform_src_install

	local fuzzer_component_id="1188704"

	platform_fuzzer_install "${S}"/OWNERS \
		"${OUT}"/libhwsec_tpm1_cmk_migration_parser_fuzzer \
		--comp "${fuzzer_component_id}"

	platform_fuzzer_install "${S}"/OWNERS \
		"${OUT}"/libhwsec_tpm2_backend_fuzzer \
		--comp "${fuzzer_component_id}" \
		--dict "${S}"/fuzzers/testdata/tpm2_commands.dict
}

WHALEOS_PATCHES=(
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
