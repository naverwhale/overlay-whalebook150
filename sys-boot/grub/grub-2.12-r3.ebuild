# Copyright 2010 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"

inherit autotools bash-completion-r1 eutils flag-o-matic cros-toolchain-funcs multiprocessing

DESCRIPTION="GNU GRUB boot loader"
HOMEPAGE="https://www.gnu.org/software/grub/"
SRC_URI="mirror://gnu/${PN}/${P}.tar.xz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="*"

PLATFORMS=( "efi" )

PATCHES=(
	"${FILESDIR}/0001-Forward-port-ChromeOS-specific-GRUB-environment-vari.patch"
	"${FILESDIR}/0002-Forward-port-gptpriority-command-to-GRUB-2.00.patch"
	"${FILESDIR}/0003-grub-2.12-image-base.patch"
	"${FILESDIR}/1001-Add-hidden-hotkey-to-enter-menu.patch"
	"${FILESDIR}/1002-Apply-whaleos-menu-entry-and-delete-cli-edit.patch"
)

BDEPEND="
	>=sys-devel/flex-2.5.35
	sys-devel/bison
	sys-apps/help2man
	app-arch/xz-utils
"

grub_targets() {
	case ${ARCH} in
	x86|amd64) echo "x86_64";;
	arm64) echo "arm64";;
	*) die "Unsupported ARCH ${ARCH}";;
	esac
}

src_prepare() {
	default

	# Add a file that was accidentally left out of the 2.12 tarball:
	# https://lists.gnu.org/archive/html/grub-devel/2023-12/msg00066.html
	echo "depends bli part_gpt" > "${S}/grub-core/extra_deps.lst"

	bash autogen.sh || die
	# Fix timestamps to prevent unnecessary rebuilding
	find "${S}" -exec touch -r "${S}/configure" {} +
}

src_configure() {
	# GRUB doesn't compile with clang on arm64 (b/290883718). Use gcc instead.
	use arm64 && cros_use_gcc

	tc-export TARGET_CC NM OBJCOPY STRIP
	export TARGET_NM="${NM}"
	export TARGET_OBJCOPY="${OBJCOPY}"
	export TARGET_STRIP="${STRIP}"

	# --gc-sections must be used with other flags including --entry, --undefined
	# and --gc-keep-exported to specify which symbols should be kept. GRUB
	# modules contain an additional section module_license which contains only a
	# string without any symbols. The flags mentioned before can only exclude
	# symbols, not sections from gc. Therefore to prevent module_license from
	# being stripped by gc, we need to filter it from ldflags.
	filter-ldflags "-Wl,--gc-sections"

	local platform target
	multijob_init
	for platform in "${PLATFORMS[@]}" ; do
		for target in $(grub_targets) ; do
			mkdir -p "${target}-${platform}-build"
			pushd "${target}-${platform}-build" >/dev/null || die

			# Set the --target to the current --host by default.  This is what
			# autoconf will basically do.  However, if we're building a target
			# that doesn't match the current host (e.g. building a 32-bit EFI
			# for a x86_64 board), override it so grub will build the right file.
			local ctarget="${CHOST}"
			case ${CHOST}:${target} in
			i?86-*:x86_64|x86_64-*:i386) ctarget="${target}";;
			esac

			# GRUB defaults to a --program-prefix set based on target
			# platform; explicitly set it to nothing to install unprefixed
			# tools.  https://savannah.gnu.org/bugs/?39818
			ECONF_SOURCE="${S}" multijob_child_init econf \
				--disable-werror \
				--disable-grub-mkfont \
				--disable-grub-mount \
				--disable-device-mapper \
				--disable-efiemu \
				--disable-libzfs \
				--disable-nls \
				--enable-quiet-boot \
				--sbindir=/sbin \
				--bindir=/bin \
				--libdir="/$(get_libdir)" \
				--with-platform="${platform}" \
				--target="${ctarget}" \
				--program-prefix=
			popd >/dev/null || die
		done
	done
	multijob_finish
}

src_compile() {
	local platform target
	multijob_init
	for platform in "${PLATFORMS[@]}" ; do
		for target in $(grub_targets) ; do
			multijob_child_init \
				emake -C "${target}-${platform}-build"
		done
	done
	multijob_finish
}

src_install() {
	local platform target
	# The installations have several file conflicts that prevent
	# parallel installation.
	for platform in "${PLATFORMS[@]}" ; do
		for target in $(grub_targets) ; do
			emake -C "${target}-${platform}-build" DESTDIR="${D}" \
				install bashcompletiondir="$(get_bashcompdir)"

			# Disable stripping for several file types,
			# otherwise the image produced by grub-mkimage
			# does not boot.
			local -a modules=( "${D}/$(get_libdir)/grub/${target}-${platform}"/*.{img,mod,module} )
			dostrip -x "${modules[@]#"${D}"}"
		done
	done
}
