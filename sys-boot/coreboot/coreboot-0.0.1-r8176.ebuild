# Copyright 2014 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

# Change this version number when any change is made to configs/files under
# coreboot and an auto-revbump is required.
# VERSION=REVBUMP-0.0.73

EAPI=7

# Drop the version number from the path so we can get RBE cache hits between
# different versions.
CROS_WORKON_COMMIT=("b55edf898dc19f766d725f33557b8cdcfff227f5" "1bdd25d141ea6b07ddc06210defc55a8bfab3f0f" "34fbbe62cc1832016e956d55d72b4aba606b7e21" "b7d5b2d6a6dd05874d86ee900ff441d261f9034c")
CROS_WORKON_TREE=("ced6c0c7d007b4651db20b0b640011aba44384cb" "852944c2c35514b2ac973cf937567319105861f4" "dba76947d5708a928baed0287433c717906dd4af" "c0433b88f972fa26dded401be022c1c026cd644e")
S="${WORKDIR}/${PN}"

CROS_WORKON_PROJECT=(
	"chromiumos/third_party/coreboot"
	"chromiumos/third_party/arm-trusted-firmware"
	"chromiumos/platform/vboot_reference"
	"chromiumos/third_party/cbootimage"
)
CROS_WORKON_LOCALNAME=(
	"coreboot"
	"arm-trusted-firmware"
	"../platform/vboot_reference"
	"cbootimage"
)
CROS_WORKON_DESTDIR=(
	"${S}"
	"${S}/3rdparty/arm-trusted-firmware"
	"${S}/3rdparty/vboot"
	"${S}/util/nvidia/cbootimage"
)

CROS_WORKON_EGIT_BRANCH=(
	"main"
	"master"
	"main"
	"master"
)

PYTHON_COMPAT=( python3_11 )

# Use our own reclient version.
CROS_REMOTEEXEC_RECLIENT_PATH="${WORKDIR}/reclient"
# We have a read only src directory so write temp files elsewhere.
# shellcheck disable=SC2034
CROS_REMOTEEXEC_DOWNLOAD_TEMP_DIR="${T}/reclient"

inherit cros-workon cros-toolchain-funcs cros-unibuild coreboot-sdk coreboot-sdk-ap-dependencies cros-sanitizers python-any-r1 cros-remoteexec

DESCRIPTION="coreboot firmware"
HOMEPAGE="http://www.coreboot.org"
LICENSE="GPL-2"
KEYWORDS="*"

# SOC
IUSE="amd_cpu intel_cpu"
# GSC
IUSE="${IUSE} mocktpm ti50_onboard vboot_disable_cbfs_integration"
# AMD chipsets
IUSE="${IUSE} chipset_cezanne chipset_mendocino chipset_phoenix chipset_stoneyridge"
# Debug
IUSE="${IUSE} fw_debug intel_debug intel-compliance-test-mode"
# Qualcomm QDUTT
IUSE="${IUSE} qualcomm_qdutt"
# Qualcomm ramdump
IUSE="${IUSE} qualcomm_ramdump"
# QCLib log-level handling
IUSE="${IUSE} qclib_nodebug"
# Logging
IUSE="${IUSE} quiet quiet-cb verbose"
# Flashrom Emulator
IUSE="${IUSE} em100-mode"
# Common libraries
IUSE="${IUSE} fsp memmaps mma private_fsp_headers rmt vmx"
IUSE="${IUSE} unibuild"

# virtual/coreboot-private-files is deprecated. When adding a new board you
# should add the coreboot(-private)-files-{board/chipset} ebuilds into the
# public/private overlays, and avoid creating virtual packages.
# See b/178642474
IUSE="${IUSE} coreboot-files-board coreboot-files-chipset"
IUSE="${IUSE} coreboot-private-files-board coreboot-private-files-chipset"

IUSE="${IUSE} +fsp_gop"

# FPDT - FSP performance data
IUSE="${IUSE} fsp_perf"

# Firmware Boot Splash Screen
IUSE="${IUSE} firmware-bootsplash"

# Use Unsigned PSP verstage
IUSE="${IUSE} unsigned-psp-verstage"

# No pre-unibuild boards build firmware on ToT anymore.  Assume
# unibuild to keep ebuild clean.
REQUIRED_USE="unibuild"

# Use unsigned-psp-verstage only in amd_cpu
REQUIRED_USE+=" unsigned-psp-verstage? ( amd_cpu )"

# Disable binary checks for PIE and relative relocatons.
# Don't strip to ease remote GDB use (cbfstool strips final binaries anyway).
# This is only okay because this ebuild only installs files into
# ${SYSROOT}/firmware, which is not copied to the final system image.
RESTRICT="binchecks strip"

# Restrict network sandbox to allow reclient to interact with the RBE instance.
# Do not make any changes that make any other network interactions without
# getting approval from the ChromeOS Build team.
RESTRICT+=" network-sandbox"

# Disable warnings for executable stack.
QA_EXECSTACK="*"

# Python is required for coreboot utilities such as util/mtkheader/gen-bl-img.py.
BDEPEND="
	${PYTHON_DEPS}
	app-arch/unzip
	net-misc/rsync
	sys-apps/coreboot-utils
	app-misc/ca-certificates
"

DEPEND="
	coreboot-files-board? ( sys-boot/coreboot-files-board:= )
	coreboot-files-chipset? ( sys-boot/coreboot-files-chipset:= )
	coreboot-private-files-board? ( sys-boot/coreboot-private-files-board:= )
	coreboot-private-files-chipset? ( sys-boot/coreboot-private-files-chipset:= )
	firmware-bootsplash? ( sys-boot/firmware-bootsplash-assets:= )
	virtual/coreboot-private-files
	chipset_stoneyridge? ( sys-boot/amd-firmware:= )
	chipset_cezanne? ( sys-boot/amd-cezanne-fsp:= )
	chipset_mendocino? ( sys-boot/amd-mendocino-fsp:= )
	chipset_phoenix? ( sys-boot/amd-phoenix-fsp:= )
	chromeos-base/chromeos-config:=
	dev-libs/nss:=
	"

# While this package is never actually executed, we still need to specify
# RDEPEND. A binary version of this package could exist that was built using an
# outdated version of chromeos-config. Without the RDEPEND this stale binary
# package is considered valid by the package manager. This is problematic
# because we could have two binary packages installed having been build with
# different versions of chromeos-config. By specifying the RDEPEND we force
# the package manager to ensure the two versions use the same chromeos-config.
RDEPEND="${DEPEND}
	!sys-boot/amd-picasso-fsp
	"

RECLIENT_VERSION="0.176.0.8c46330a-gomaip"
SRC_URI="
	cipd://infra/rbe/client/linux-amd64:re_client_version:${RECLIENT_VERSION} -> reclient-${RECLIENT_VERSION}.zip
"

coreboot-sdk_enable i386-elf amd64
coreboot-sdk_enable x86_64-elf amd64
coreboot-sdk_enable aarch64-elf arm64
coreboot-sdk_enable arm-eabi arm
coreboot-sdk_enable arm-eabi amd_cpu
coreboot-sdk_enable iasl

src_unpack() {
	coreboot-sdk_src_unpack

	if cros-remoteexec_use_remoteexec; then
		unzip "${DISTDIR}/reclient-${RECLIENT_VERSION}.zip" -d "${CROS_REMOTEEXEC_RECLIENT_PATH}" || die
	fi
}

PATCHES=(
	"${FILESDIR}/Remove-H1.patch"
)

set_build_env() {
	local board="$1"

	CONFIG="$(cros-workon_get_build_dir)/out/${board}.config"
	CONFIG_SERIAL="$(cros-workon_get_build_dir)/out/${board}-serial.config"
	# Strip the .config suffix
	BUILD_DIR="${CONFIG%.config}"
	BUILD_DIR_SERIAL="${CONFIG_SERIAL%.config}"
}

# Create the coreboot configuration files for a particular board. This
# creates a standard config and a serial config.
# Args:
#   $1: board name
#   $2: libpayload build target (for config.baseboard files)
create_config() {
	local board="$1"
	local base_board="$2"

	touch "${CONFIG}"

	if use rmt; then
		echo "CONFIG_MRC_RMT=y" >> "${CONFIG}"
	fi
	if use vmx; then
		elog "   - enabling VMX"
		echo "CONFIG_ENABLE_VMX=y" >> "${CONFIG}"
	fi
	if use quiet-cb; then
		# Suppress console spew if requested.
		cat >> "${CONFIG}" <<EOF
CONFIG_DEFAULT_CONSOLE_LOGLEVEL=3
# CONFIG_DEFAULT_CONSOLE_LOGLEVEL_8 is not set
CONFIG_DEFAULT_CONSOLE_LOGLEVEL_3=y
EOF
	fi
	if use mocktpm; then
		echo "CONFIG_VBOOT_MOCK_SECDATA=y" >> "${CONFIG}"
	fi
	if use mma; then
		echo "CONFIG_MMA=y" >> "${CONFIG}"
	fi
	if use intel_debug; then
		echo "CONFIG_SOC_INTEL_DEBUG_CONSENT=y" >> "${CONFIG}"
		sed -E -i 's/(CONFIG_LOCK_MANAGEMENT_ENGINE=)y/\1n/g' "${CONFIG}"
	fi
	if use ti50_onboard; then
		echo "CONFIG_CBFS_VERIFICATION=y" >> "${CONFIG}"
	fi
	if use ti50_onboard && ! use vboot_disable_cbfs_integration; then
		echo "CONFIG_VBOOT_CBFS_INTEGRATION=y" >> "${CONFIG}"
	fi
	if use fw_debug; then
		echo "CONFIG_BUILDING_WITH_DEBUG_FSP=y" >> "${CONFIG}"
	fi
	if use intel-compliance-test-mode; then
		echo "CONFIG_SOC_INTEL_COMPLIANCE_TEST_MODE=y" >> "${CONFIG}"
	fi
	if use qualcomm_ramdump; then
		echo "CONFIG_QC_SDI_ENABLE=y" >> "${CONFIG}"
	fi
	if use qualcomm_qdutt; then
		echo "CONFIG_QC_QDUTT_ENABLE=y" >> "${CONFIG}"
	fi
	local version=$("${CHROOT_SOURCE_ROOT}"/src/third_party/chromiumos-overlay/chromeos/config/chromeos_version.sh |grep "^[[:space:]]*CHROMEOS_VERSION_STRING=" |cut -d= -f2 | tr - _)
	{
		# enable common GBB flags for development
		echo "CONFIG_GBB_FLAG_DEV_SCREEN_SHORT_DELAY=y"
		echo "CONFIG_GBB_FLAG_DISABLE_FW_ROLLBACK_CHECK=y"
		echo "CONFIG_GBB_FLAG_FORCE_DEV_BOOT_USB=y"
		echo "CONFIG_GBB_FLAG_FORCE_DEV_SWITCH_ON=y"
		echo "CONFIG_VBOOT_FWID_VERSION=\".${version}\""
	} >> "${CONFIG}"
	if use em100-mode; then
		einfo "Enabling em100 mode via CONFIG_EM100 (slower SPI flash)"
		echo "CONFIG_EM100=y" >> "${CONFIG}"
	fi
	# Use FSP's GOP in favor of coreboot's Ada based Intel graphics init
	# which we don't include at this time. A no-op on non-FSP/GOP devices.
	if use fsp_gop; then
		echo "CONFIG_RUN_FSP_GOP=y" >> "${CONFIG}"
	fi

	if use fsp_perf; then
		echo "CONFIG_DISPLAY_FSP_TIMESTAMPS=y" >> "${CONFIG}"
	fi

	# Override the automatic options created above with board config.
	local board_config="${FILESDIR}/configs/config.${board}"
	local baseboard_config="${FILESDIR}/configs/config.baseboard.${base_board}"
	local board_config_line="CONFIG_BOARD_GOOGLE_${board^^}=y"

	if [[ -s "${baseboard_config}" ]]; then
		cat "${baseboard_config}" >> "${CONFIG}"
		# Handle the case when "${CONFIG}" does not have a newline in the end.
		echo >> "${CONFIG}"
	fi

	if [[ -s "${board_config}" ]]; then
		cat "${board_config}" >> "${CONFIG}"
		# Handle the case when "${CONFIG}" does not have a newline in the end.
		echo >> "${CONFIG}"
	else
		# Auto-generate board config with CONFIG_BOARD_GOOGLE_*=y
		einfo "Auto-generate ${board_config_line}"
		echo "${board_config_line}" >> "${CONFIG}"
	fi

	# Override mainboard vendor if needed.
	if [[ -n "${SYSTEM_OEM}" ]]; then
		echo "CONFIG_MAINBOARD_VENDOR=\"${SYSTEM_OEM}\"" >> "${CONFIG}"
	fi
	if [[ -n "${SYSTEM_OEM_VENDOR_ID}" ]]; then
		echo "CONFIG_SUBSYSTEM_VENDOR_ID=${SYSTEM_OEM_VENDOR_ID}" >> "${CONFIG}"
	fi
	if [[ -n "${SYSTEM_OEM_DEVICE_ID}" ]]; then
		echo "CONFIG_SUBSYSTEM_DEVICE_ID=${SYSTEM_OEM_DEVICE_ID}" >> "${CONFIG}"
	fi
	if [[ -n "${SYSTEM_OEM_ACPI_ID}" ]]; then
		echo "CONFIG_ACPI_SUBSYSTEM_ID=\"${SYSTEM_OEM_ACPI_ID}\"" >> "${CONFIG}"
	fi

	if use private_fsp_headers; then
		local fspsocname=$(grep "CONFIG_FSP_M_FILE" "${CONFIG}" | cut -d '"' -f2 | cut -d '/' -f4)
		echo "CONFIG_FSP_HEADER_PATH=\"3rdparty/blobs/intel/${fspsocname}/fsp/PartialHeader/Include\"" >> "${CONFIG}"
	fi

	if use unsigned-psp-verstage; then
		sed -i -e '/^CONFIG_PSP_VERSTAGE_FILE/d' "${CONFIG}"
	fi

	if cros-remoteexec_use_remoteexec; then
		echo "CONFIG_CCACHE=y" >> "${CONFIG}"
	fi

	# Serial config
	cp "${CONFIG}" "${CONFIG_SERIAL}"
	local board_fwserial="${FILESDIR}/configs/fwserial.${board}"
	if [[ ! -f "${board_fwserial}" && -n "${base_board}" ]]; then
		board_fwserial="${FILESDIR}/configs/fwserial.${base_board}"
	fi

	cat "${FILESDIR}/configs/fwserial.default" >> "${CONFIG_SERIAL}" || die
	# Handle the case when "${CONFIG_SERIAL}" does not have a newline in the end.
	echo >> "${CONFIG_SERIAL}"
	if [[ -s "${board_fwserial}" ]]; then
		cat "${board_fwserial}" >> "${CONFIG_SERIAL}" || die
		# Handle the case when "${CONFIG_SERIAL}" does not have a newline in the end.
		echo >> "${CONFIG_SERIAL}"
	fi

	if grep -q "^CONFIG_ANY_TOOLCHAIN=y" "${CONFIG}"; then
		die "Drop ANY_TOOLCHAIN from ${CONFIG}: we don't support it anymore."
	fi

	einfo "Configured ${CONFIG} for board ${board} in ${BUILD_DIR}"
}

src_prepare() {
	local froot="${SYSROOT}/firmware"
	local privdir="${SYSROOT}/firmware/coreboot-private"
	local file

	# Start reclient early on so that if it fails we can skip setting up
	# the build to use it.
	cros-remoteexec_initialize --disable-on-failure

	default

	export GENERIC_COMPILER_PREFIX="invalid"

	# `cros-workon_get_build_dir` be default returns `${WORKDIR}/build`.
	# If we concat the models to the path we end up with
	# `${WORKDIR}/build/${MODEL}`. As part of the RBE wrapper we need to
	# replace all absolute paths with relative paths. So if we were to
	# `s|${SYSROOT}|../../${SYSROOT}|` where SYSROOT is normally
	# `/build/${BOARD}` we run into issues with the
	# `${WORKDIR}/build/${MODEL}` naming since there are instances where
	# `${MODEL}` == `${BOARD}`. To avoid this append an `out` directory
	# to the path so that the naive replacement works correctly.
	mkdir -p "$(cros-workon_get_build_dir)/out"

	if [[ -d "${privdir}" ]]; then
		while read -d $'\0' -r file; do
			rsync --recursive --links --executability \
				"${file}" ./ || die
		done < <(find "${privdir}" -maxdepth 1 -mindepth 1 -print0)
	fi

	cp -a "${FILESDIR}/3rdparty/"* 3rdparty

	if cros-remoteexec_use_remoteexec; then
		# Portage normally builds packages in
		# `${PORTAGE_TMPDIR}/${CATEGORY}/{$PVR}`. Create a "sysroot"
		# symlink inside the `${WORKDIR}` so that we can use the WORKDIR
		# as the execroot. This lets us avoid including the version
		# number in the CWD or any of the paths.
		ln -s "${SYSROOT}" "${WORKDIR}/sysroot"

		# Hack for reclient so we always create the CWD.
		# b/392166811
		touch ".empty" "3rdparty/vboot/.empty"
	fi

	local name
	local coreboot
	local libpayload
	while read -r name; do
		read -r coreboot
		read -r libpayload
		set_build_env "${coreboot}"
		create_config "${coreboot}" "${libpayload}"
	done < <(cros_config_host "get-firmware-build-combinations" \
		coreboot,libpayload || die)

	# With multiple builds running in parallel, we do not support the source
	# files themselves being modified while building coreboot.
	# Make the source file directory read-only to safe guard against any
	# changes landing that could make the build flaky.
	# https://devmanual.gentoo.org/eclass-reference/ebuild/index.html
	# S = ${WORKDIR}/${P}
	#     Contains the path to the temporary build directory. This variable is
	#     used by the functions src_compile and src_install. Both are executed
	#     with S as the current directory. This variable may be modified to
	#     match the extraction directory of a tarball for the package.
	chmod -R a-w "${S}"
}

add_fw_blob() {
	local rom="$1"
	local cbname="$2"
	local blob="$3"
	local cbhash="${cbname%.bin}.hash"
	local hash="${blob%.bin}.hash"

	cbfstool "${rom}" add -r FW_MAIN_A,FW_MAIN_B -t raw -c lzma \
		-f "${blob}" -n "${cbname}" || die
	cbfstool "${rom}" add -r FW_MAIN_A,FW_MAIN_B -t raw -c none \
		-f "${hash}" -n "${cbhash}" || die
}

# Build coreboot in parallel
#   $@: Configs to build
make_coreboot() {
	local CB_OPTS=(
		HOSTCC="$(tc-getBUILD_CC)"
		HOSTCXX="$(tc-getBUILD_CXX)"
		HOSTPKGCONFIG="$(tc-getBUILD_PKG_CONFIG)"
		xcompile="${WORKDIR}/xcompile"
	)
	use quiet && CB_OPTS+=( "V=0" )
	use verbose && CB_OPTS+=( "V=1" )
	if use intel_cpu && use em100-mode; then
		CB_OPTS+=(EM100_IDF=1)
	fi

	emake -f "${FILESDIR}/coreboot.make" "${CB_OPTS[@]}" configs="$*"
}

# Add fw blobs to the coreboot.rom.
#   $1: Build directory to use (e.g. "build_serial")
#   $2: Build target build (e.g. "pyro")
add_fw_blobs() {
	local builddir="$1"
	local build_target="$2"
	local froot="${SYSROOT}/firmware/${build_target}"
	local fblobroot="${SYSROOT}/firmware"

	local blob
	local cbname
	# shellcheck disable=SC2154 # FW_BLOBS may be provided by overlays.
	for blob in ${FW_BLOBS}; do
		local blobfile="${fblobroot}/${blob}"

		# Use per-board blob if available
		if [[ -e "${froot}/${blob}" ]]; then
			blobfile="${froot}/${blob}"
		fi

		cbname=$(basename "${blob}")
		add_fw_blob "${builddir}/coreboot.rom" "${cbname}" \
			"${blobfile}" || die
	done

	if [[ -d "${froot}/cbfs" ]]; then
		die "something is still using ${froot}/cbfs, which is deprecated."
	fi
}

# TODO(b/392641146): Generate this as part of subtool package
generate_toolchain_inputs() {
	local arches=(
		"${COREBOOT_SDK_ENABLED_TOOLCHAINS[@]%%:*}"
	)
	local arch
	for arch in "${arches[@]}"; do
		if [[ ! -e "${WORKDIR}/coreboot-sdk/${arch}" ]]; then
			continue
		fi

		(
			cd "${WORKDIR}/coreboot-sdk/bin" || die
			find . -type f -iname "${arch}-gcc*" \! -iname "*remote_toolchain_inputs" || die
			find ../lib/ -iname gcc -prune -o -type f -print || die
			find "../lib/gcc/${arch}" || die
			find "../${arch}/bin" || die
		) | sort > "${WORKDIR}/coreboot-sdk/bin/${arch}-gcc_remote_toolchain_inputs"
	done
}

src_compile() {
	# Set KERNELREVISION (really coreboot revision) to the ebuild revision
	# number followed by a dot and the first seven characters of the git
	# hash. The name is confusing but consistent with the coreboot
	# Makefile.
	# shellcheck disable=SC2154 # VCSID is provided by cros-workon.eclass.
	local sha1v="${VCSID/*-/}"
	export KERNELREVISION=".${PV}.${sha1v:0:7}"

	export CROSS_COMPILE_x86=${COREBOOT_SDK_PREFIX_x86_32}
	export CROSS_COMPILE_x64=${COREBOOT_SDK_PREFIX_x86_64}
	export CROSS_COMPILE_arm64=${COREBOOT_SDK_PREFIX_arm64}
	export CROSS_COMPILE_arm=${COREBOOT_SDK_PREFIX_arm}

	if cros-remoteexec_use_remoteexec; then
		# Adds the "ccache" binary to the path.
		PATH="${FILESDIR}/reclient:${PATH}"

		generate_toolchain_inputs
	fi

	local -a configs

	while read -r name; do
		read -r coreboot

		set_build_env "${coreboot}"
		configs+=("${CONFIG}")
		configs+=("${CONFIG_SERIAL}")
	done < <(cros_config_host "get-firmware-build-combinations" coreboot || die)

	# xcompile can be expensive to generate, so only do it once instead of
	# having each individual build compute its own.
	einfo "Probing cross compilers"
	./util/xcompile/xcompile "${COREBOOT_SDK_PREFIX}/bin" \
		> "${WORKDIR}/xcompile" || die

	make_coreboot "${configs[@]}"

	cros-remoteexec_shutdown

	while read -r name; do
		read -r coreboot

		set_build_env "${coreboot}"
		add_fw_blobs "${BUILD_DIR}" "${coreboot}"
		add_fw_blobs "${BUILD_DIR_SERIAL}" "${coreboot}"
		if use fsp; then
			cbfstool "${BUILD_DIR_SERIAL}/coreboot.rom" add-int -i $(usex fw_debug 3 0) \
				 -n option/fsp_pcd_debug_level || die
			cbfstool "${BUILD_DIR_SERIAL}/coreboot.rom" add-int -i $(usex fw_debug 5 0) \
				 -n option/fsp_mrc_debug_level || die
		fi
		# With `qclib_nodebug` flag is enabled, the option
		# `qclib_debug_level` is set to `0x0`. User can set `qclib_debug_level`
		# option to non-zero value to enable QcLib UART debug prints using cbfstool.
		cbfstool "${BUILD_DIR_SERIAL}/coreboot.rom" add-int -i $(usex qclib_nodebug 0 1) \
			 -n option/qclib_debug_level || die
	done < <(cros_config_host "get-firmware-build-combinations" coreboot || die)
}

# Install files into /firmware
# Args:
#   $1: The build combination name
#   $2: The coreboot build target
do_install() {
	local build_combination="$1"
	local build_target="$2"
	local dest_dir="/firmware"
	local mapfile

	if [[ -n "${build_target}" ]]; then
		dest_dir+="/${build_target}"
		einfo "Installing coreboot ${build_target} into ${dest_dir}"
	fi
	insinto "${dest_dir}"

	newins "${BUILD_DIR}/coreboot.rom" coreboot.rom
	newins "${BUILD_DIR_SERIAL}/coreboot.rom" coreboot.rom.serial

	OPROM=$( awk 'BEGIN{FS="\""} /CONFIG_VGA_BIOS_FILE=/ { print $2 }' \
		"${CONFIG}" )
	CBFSOPROM=pci$( awk 'BEGIN{FS="\""} /CONFIG_VGA_BIOS_ID=/ { print $2 }' \
		"${CONFIG}" ).rom
	FSP=$( awk 'BEGIN{FS="\""} /CONFIG_FSP_FILE=/ { print $2 }' \
		"${CONFIG}" )
	if [[ -n "${FSP}" ]]; then
		newins "${FSP}" fsp.bin
	fi
	# Save the psp_verstage binary for signing on AMD platforms
	if [[ -e "${BUILD_DIR}/psp_verstage.bin" ]]; then
		# Extract the path of the signing token from coreboot.config
		# Eg. 3rdparty/blobs/mainboard/google/skyrim/skyrim_shiraz.stkn
		SIGNING_TOKEN="$( awk 'BEGIN{FS="\""} /CONFIG_PSP_VERSTAGE_SIGNING_TOKEN=/ \
					{ print $2 }' "${CONFIG}" )"
		# Prepare the psp_verstage for signing if the signing token exists
		if [[ -n "${SIGNING_TOKEN}" ]]; then
			insinto "/firmware/psp_verstage_to_sign"
			local prep_verstage="3rdparty/blobs/mainboard/google/utils/prepare_verstage_to_sign.sh"
			"${prep_verstage}" "${BUILD_DIR}/psp_verstage.bin" "${SIGNING_TOKEN}" \
					"${BUILD_DIR}/psp_verstage_to_sign.bin" || die "Error preparing: ${BUILD_DIR}/psp_verstage.bin"
			newins "${BUILD_DIR}/psp_verstage_to_sign.bin" \
					"${build_target}"_psp_verstage.bin
		fi
		# Save the unsigned psp_verstage too for later reference
		insinto "/firmware/unsigned_psp_verstage"
		newins "${BUILD_DIR}/psp_verstage.bin" "${build_target}"_psp_verstage.bin
		# Back to the original destination for rest of the installation
		insinto "${dest_dir}"
	fi
	if [[ -n "${OPROM}" ]]; then
		newins "${OPROM}" "${CBFSOPROM}"
	fi
	if use memmaps; then
		for mapfile in "${BUILD_DIR}"/cbfs/fallback/*.map
		do
			doins "${mapfile}"
		done
	fi
	newins "${CONFIG}" coreboot.config
	newins "${CONFIG_SERIAL}" coreboot_serial.config

	# Keep binaries with debug symbols around for crash dump analysis
	if [[ -s "${BUILD_DIR}/bl31.elf" ]]; then
		newins "${BUILD_DIR}/bl31.elf" bl31.elf
		newins "${BUILD_DIR_SERIAL}/bl31.elf" bl31.serial.elf
	fi
	insinto "${dest_dir}"/coreboot
	doins "${BUILD_DIR}"/cbfs/fallback/*.debug
	nonfatal doins "${BUILD_DIR}"/cbfs/fallback/bootblock.bin
	insinto "${dest_dir}"/coreboot_serial
	doins "${BUILD_DIR_SERIAL}"/cbfs/fallback/*.debug
	nonfatal doins "${BUILD_DIR_SERIAL}"/cbfs/fallback/bootblock.bin

	# coreboot's static_fw_config.h is copied into libpayload include
	# directory.
	insinto "/firmware/${build_combination}/libpayload/libpayload/include"
	doins "${BUILD_DIR}/static_fw_config.h"
	einfo "Installed static_fw_config.h into libpayload include directory"
}

src_configure() {
	sanitizers-setup-env
	default
}

src_install() {
	while read -r name; do
		read -r coreboot

		set_build_env "${coreboot}"
		do_install "${name}" "${coreboot}"
	done < <(cros_config_host "get-firmware-build-combinations" coreboot || die)
}
