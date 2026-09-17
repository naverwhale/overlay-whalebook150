# Copyright 2020 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"20bdaf62d1bfa3654751447b9647b0dc01945b62"  # biod
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"4934b6b332f2a3db7a26bad9f888607a4f12b440"  # libec
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
)
CROS_WORKON_USE_VCSID="1"
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_SUBTREE="biod common-mk libec .gn"

PLATFORM_SUBDIR="libec"

inherit cros-workon platform

DESCRIPTION="Embedded Controller Library for Chromium OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/libec"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="cros_host"

COMMON_DEPEND="
	chromeos-base/chromeos-ec-headers:=
	!cros_host? ( chromeos-base/power_manager-client:= )
	dev-cpp/abseil-cpp:=
	virtual/libusb:1=
	sys-apps/flashmap:=
"

RDEPEND="
	${COMMON_DEPEND}
	"

DEPEND="
	${COMMON_DEPEND}
	chromeos-base/system_api
"

src_install() {
	platform_src_install

	# Install fuzzers.
	local fuzzer_component_id="782045"
	local fuzz_targets=(
		"libec_ec_panicinfo_fuzzer"
	)
	local fuzz_target
	for fuzz_target in "${fuzz_targets[@]}"; do
		platform_fuzzer_install "${S}"/OWNERS "${OUT}"/"${fuzz_target}" \
			--comp "${fuzzer_component_id}"
	done
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-libec.patch"
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
