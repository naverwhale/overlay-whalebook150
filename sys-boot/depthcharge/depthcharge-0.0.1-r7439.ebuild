# Copyright 2012 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
CROS_WORKON_COMMIT=("9945cf17d743119ae246c9c244898e0b2fa368d4" "34fbbe62cc1832016e956d55d72b4aba606b7e21" "b55edf898dc19f766d725f33557b8cdcfff227f5")
CROS_WORKON_TREE=("9a317453c5aadbbfdb6592f24155cd3bd27a0eb9" "dba76947d5708a928baed0287433c717906dd4af" "ced6c0c7d007b4651db20b0b640011aba44384cb")
CROS_WORKON_PROJECT=(
	"chromiumos/platform/depthcharge"
	"chromiumos/platform/vboot_reference"
	"chromiumos/third_party/coreboot"
)

PYTHON_COMPAT=( python3_11 )

# Disable binary checks for PIE and relative relocatons.
# Don't strip to ease remote GDB use (cbfstool strips final binaries anyway).
# This is only okay because this ebuild only installs files into
# ${SYSROOT}/firmware, which is not copied to the final system image.
RESTRICT="binchecks strip"

inherit cros-workon cros-unibuild cros-sanitizers python-any-r1 coreboot-sdk coreboot-sdk-ap-dependencies

DESCRIPTION="coreboot's depthcharge payload"
HOMEPAGE="http://www.coreboot.org"
LICENSE="GPL-2"
KEYWORDS="*"
IUSE="avb fwconsole mocktpm pd_sync unibuild verbose debug
	physical_presence_power physical_presence_recovery test
	intel-compliance-test-mode"

# No pre-unibuild boards build firmware on ToT anymore.  Assume
# unibuild to keep ebuild clean.
REQUIRED_USE="unibuild"

DEPEND="
	sys-boot/coreboot:=
	chromeos-base/chromeos-ec-headers:=
	sys-boot/libpayload:=
	chromeos-base/chromeos-config:=
"

# While this package is never actually executed, we still need to specify
# RDEPEND. A binary version of this package could exist that was built using an
# outdated version of chromeos-config. Without the RDEPEND this stale binary
# package is considered valid by the package manager. This is problematic
# because we could have two binary packages installed having been build with
# different versions of chromeos-config. By specifying the RDEPEND we force
# the package manager to ensure the two versions use the same chromeos-config.
RDEPEND="${DEPEND}"

BDEPEND="
	dev-python/kconfiglib
	test? (
		$(python_gen_any_dep '
			dev-python/pillow[${PYTHON_USEDEP}]
		')
		dev-util/cmake
		dev-util/cmocka
	)
"

CROS_WORKON_LOCALNAME=(
	"../platform/depthcharge"
	"../platform/vboot_reference"
	"../third_party/coreboot"
)
VBOOT_REFERENCE_DESTDIR="${S}/vboot_reference"
COREBOOT_DESTDIR="${S}/coreboot"
CROS_WORKON_DESTDIR=(
	"${S}/depthcharge"
	"${VBOOT_REFERENCE_DESTDIR}"
	"${COREBOOT_DESTDIR}"
)

# Disable warnings for executable stack.
QA_EXECSTACK="*"

coreboot-sdk_enable i386-elf amd64
coreboot-sdk_enable x86_64-elf amd64
coreboot-sdk_enable aarch64-elf arm64
coreboot-sdk_enable arm-eabi arm
coreboot-sdk_enable iasl

python_check_deps() {
	use test || return 0

	python_has_version -b "dev-python/pillow[${PYTHON_USEDEP}]"
}

pkg_setup() {
	cros-workon_pkg_setup
	python-any-r1_pkg_setup
}

PATCHES=(
	"${FILESDIR}/Remove-H1.patch"
)

# Build depthcharge with common options.
# Usage example: dc_make build/nipperkin/{depthcharge.elf,dev.elf}
# Args:
#   $@: Targets to build
#
# Builds the various output files for depthcharge:
#   depthcharge.elf   - normal image
#   dev.elf           - developer image
#   netboot.elf       - network image
# In addition, .map files are produced for each image.
dc_make() {
	local OPTS=(
		"EC_HEADERS=${SYSROOT}/usr/include/chromeos/ec"
	)

	use verbose && OPTS+=( "V=1" )
	use debug && OPTS+=( "SOURCE_DEBUG=1" )

	emake -f "${FILESDIR}/depthcharge.make" "${OPTS[@]}" "$@"
}

# Build the depthcharge config for the current board.
# Args
#   $1: board to build (depthcharge build target)
#   $2: base board of the board (libpayload build target)
#   $3: build directory
#   $4: recovery input method
#   $5: detachable ui enabled status ("True" for enabled)
gen_config() {
	local board="$1"
	local baseboard="$2"
	local builddir="$3"
	local recovery_input="$4"
	local config_detachable="$5"

	local defconfig="${builddir}/depthcharge.defconfig"
	local baseboard_defconfig="configs/config.baseboard.${baseboard}"
	local board_defconfig="configs/config.${board}"

	touch "${defconfig}"
	chmod +w "${defconfig}"

	if use avb ; then
		echo "CONFIG_FASTBOOT_IN_PROD=y" >> "${defconfig}"
	fi
	if use mocktpm ; then
		echo "CONFIG_MOCK_TPM=y" >> "${defconfig}"
	fi
	if use intel-compliance-test-mode; then
		echo "CONFIG_FIRMWARE_SHELL_ENTER_IMMEDIATELY=y" >> "${defconfig}"
		echo "CONFIG_SYS_PROMPT=\"${board}: \"" >> "${defconfig}"
	fi

	if [[ "${config_detachable}" == "True" ]] ; then
		echo "CONFIG_DETACHABLE=y" >> "${defconfig}"
	fi

	if [[ -z "${recovery_input}" ]] ; then
		# TODO(b/229906790) Remove this once USE flag support not longer needed
		einfo "Recovery input method not found in config. Reverting to deprecated USE flags"
		if use physical_presence_power ; then
			die "physical_presence_power is not supported in firmware UI"
		elif use physical_presence_recovery ; then
			recovery_input="RECOVERY_BUTTON"
		else
			recovery_input="KEYBOARD"
		fi
	fi
	if [[ "${recovery_input}" == "KEYBOARD" ]] ; then
		# PHYSICAL_PRESENCE_KEYBOARD=y by default
		:
	elif [[ "${recovery_input}" == "RECOVERY_BUTTON" ]] ; then
		echo "CONFIG_PHYSICAL_PRESENCE_KEYBOARD=n" >> "${defconfig}"
	elif [[ "${recovery_input}" == "POWER_BUTTON" ]] ; then
		die "Recovery input POWER_BUTTON is not supported in firmware UI"
	else
		die "Unknown recovery_input ${recovery_input}"
	fi

	if [[ -e "${baseboard_defconfig}" ]]; then
		echo -e "\n\n" >> "${defconfig}"
		cat "${baseboard_defconfig}" >> "${defconfig}"
	fi

	if [[ -e "${board_defconfig}" ]]; then
		echo -e "\n\n" >> "${defconfig}"
		cat "${board_defconfig}" >> "${defconfig}"
	else
		ewarn "${board_defconfig} does not exist!"
	fi
}

# Copy the fwconfig from libpayload to a path
# Args:
#    $1: libpayload dir
#    $2: depthcharge build directory
_copy_fwconfig() {
	local src="${1}/libpayload/include/static_fw_config.h"
	local dest="${2}/static_fw_config.h"

	if [[ -s "${src}" ]]; then
		cp "${src}" "${dest}"
		einfo "Copying ${src} into local tree"
	else
		ewarn "${src} does not exist"
	fi
}

src_configure() {
	sanitizers-setup-env
	default
}

src_compile() {
	local builddir
	local libpayload_dir

	export CROSS_COMPILE_x86=${COREBOOT_SDK_PREFIX_x86_32}
	export CROSS_COMPILE_x64=${COREBOOT_SDK_PREFIX_x86_64}
	export CROSS_COMPILE_arm64=${COREBOOT_SDK_PREFIX_arm64}
	export CROSS_COMPILE_arm=${COREBOOT_SDK_PREFIX_arm}

	# GENERIC_COMPILER_PREFIX is used by xcompile, and setting it prevents us
	# from trying to call bare host tools.
	local buildcc="$(tc-getBUILD_CC)"
	export GENERIC_COMPILER_PREFIX="${buildcc%-*}"

	# Add fake symlinks so xcompile doesn't try to call bare host tools.  Note
	# LLVM host tools work just fine, we don't actually need GCC.
	ln -sf "$(tc-getBUILD_CC)" "${COREBOOT_SDK_PREFIX}/bin/gcc"
	ln -sf "$(tc-getBUILD_CXX)" "${COREBOOT_SDK_PREFIX}/bin/g++"

	# We re-generate libpayload.xcompile, as we need the paths to our copy of
	# coreboot-sdk.
	local xcompile="${WORKDIR}/libpayload.xcompile"
	"${COREBOOT_DESTDIR}/util/xcompile/xcompile" \
		"${COREBOOT_SDK_PREFIX}/bin/" > "${xcompile}" || die

	pushd depthcharge >/dev/null || \
		die "Failed to change into ${PWD}/depthcharge"

	local name
	local libpayload
	local depthcharge
	local -a targets

	while read -r name && read -r libpayload && read -r depthcharge; do
		builddir="$(cros-workon_get_build_dir)/${depthcharge}"
		libpayload_dir="${builddir}/libpayload"
		mkdir -p "${builddir}"

		# Patch libpayload.xcompile.
		for suffix in "" .gdb; do
			cp -a "${SYSROOT}/firmware/${name}/libpayload${suffix}" \
				"${libpayload_dir}${suffix}" || die
			ln -sf "${xcompile}" \
				"${libpayload_dir}${suffix}/libpayload/libpayload.xcompile" || die
		done

		_copy_fwconfig "${libpayload_dir}" "${builddir}"

		recovery_input="$(cros_config_host get-firmware-recovery-input depthcharge "${depthcharge}")" || \
			die "Unable to determine recovery input for ${depthcharge}"
		config_detachable="$(cros_config_host get-key-value \
			/firmware/build-targets depthcharge "${depthcharge}" \
			/firmware detachable-ui --ignore-unset)" || \
			die "Unable to detachable ui config for ${depthcharge}"

		gen_config "${depthcharge}" "${libpayload}" "${builddir}" \
			"${recovery_input}" "${config_detachable}"

		targets+=(
			"${builddir}/depthcharge.elf"
			"${builddir}/dev.elf"
			"${builddir}/netboot.elf"
		)
	done < <(cros_config_host get-firmware-build-combinations libpayload,depthcharge)

	dc_make "${targets[@]}"

	popd >/dev/null || die
}

do_install() {
	local board="$1"
	local builddir="$2"
	local dstdir="/firmware"

	if [[ -n "${build_target}" ]]; then
		dstdir+="/${build_target}"
		einfo "Installing depthcharge ${build_target} into ${dstdir}"
	fi
	insinto "${dstdir}"

	pushd "${builddir}" >/dev/null || \
		die "couldn't access ${builddir}/ directory"

	local files_to_copy=(
		depthcharge.config
		{netboot,depthcharge,dev}.elf{,.map}
	)

	insinto "${dstdir}/depthcharge"
	doins "${files_to_copy[@]}"

	popd >/dev/null || die
}

src_install() {
	local build_target
	local builddir

	for build_target in $(cros_config_host \
			get-firmware-build-targets depthcharge); do
		builddir="$(cros-workon_get_build_dir)/${build_target}"

		do_install "${build_target}" "${builddir}"
	done
}

make_unittests() {
	local builddir="$1"

	local OPTS=(
		"EC_HEADERS=${SYSROOT}/usr/include/chromeos/ec"
		"CB_SOURCE=${COREBOOT_DESTDIR}"
		"LP_SOURCE=${COREBOOT_DESTDIR}/payloads/libpayload"
		"VB_SOURCE=${VBOOT_REFERENCE_DESTDIR}"
		"obj=${builddir}"
		"HOSTCC=$(tc-getBUILD_CC)"
		"HOSTCXX=$(tc-getBUILD_CXX)"
		"HOSTAR=$(tc-getBUILD_AR)"
		"HOSTAS=$(tc-getBUILD_AS)"
		"OBJCOPY=$(tc-getBUILD_OBJCOPY)"
		"OBJDUMP=$(tc-getBUILD_OBJDUMP)"
	)

	use verbose && OPTS+=( "V=1" )
	emake "${OPTS[@]}" "unit-tests"
	emake "${OPTS[@]}" "test-screenshot"
}

src_test() {
	local builddir="$(cros-workon_get_build_dir)/depthcharge.tests"

	pushd depthcharge >/dev/null || \
		die "Failed to change into ${PWD}/depthcharge"

	mkdir -p "${builddir}"
	make_unittests "${builddir}"
}
