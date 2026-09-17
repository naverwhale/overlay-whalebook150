# Copyright 2024 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=7

DESCRIPTION="Prebuilt Waydroid Android system and vendor images (LineageOS 20 x86_64)"
HOMEPAGE="https://waydroid.org"

# lineage-20.0 images from the waydroid OTA channel, x86_64 VANILLA+MAINLINE.
# Update by fetching https://ota.waydro.id/system/lineage/waydroid_x86_64/VANILLA.json
# and https://ota.waydro.id/vendor/waydroid_x86_64/MAINLINE.json, then running
# `ebuild waydroid-images-<new-date>.ebuild manifest` after updating SRC_URI.
SRC_URI="
	https://sourceforge.net/projects/waydroid/files/images/system/lineage/waydroid_x86_64/lineage-20.0-20260403-VANILLA-waydroid_x86_64-system.zip/download
		-> waydroid-system-20260403.zip
	https://sourceforge.net/projects/waydroid/files/images/vendor/waydroid_x86_64/lineage-20.0-20260428-MAINLINE-waydroid_x86_64-vendor.zip/download
		-> waydroid-vendor-20260428.zip
"

# The images are AOSP/LineageOS builds carrying a large amount of
# third-party material (MIT, Apache-2.0, BSD, GPL-2, MPL, zlib, ...).  The
# Waydroid project attribution does not cover any of it, and stock
# Apache-2.0 text carries no copyright notice, so the notices that ship
# inside the images are reproduced in the LineageOS-waydroid-images custom
# license in chromiumos-overlay/licenses/.  That file also carries the
# Apache-2.0 section 4 b notice for the platform.jar edit made below.
LICENSE="LineageOS-waydroid-images Apache-2.0"
SLOT="0"
KEYWORDS="*"
RESTRICT="mirror"

RDEPEND=""
DEPEND=""
# debugfs (e2fsprogs) is used to swap files inside system.img in place;
# python3 runs patch_platform_jar.py.  Both live in the SDK by default but
# we declare them explicitly so a slimmed-down build host still errors out
# with a clear "missing tool" message instead of a mystery src_prepare fail.
BDEPEND="app-arch/unzip sys-fs/e2fsprogs dev-lang/python:3"

S="${WORKDIR}"

# Fix Waydroid's IPlatform.removeApp -- the shipped image builds a
# PendingIntent with FLAG_UPDATE_CURRENT but neither FLAG_IMMUTABLE nor
# FLAG_MUTABLE.  Android 12+ enforces that combination is illegal, so
# every `waydroid app remove` throws IllegalArgumentException and the
# Python client logs it as `Failed with code: -3`.  installApp() in the
# same class already sets FLAG_IMMUTABLE, so the fix is a two-byte edit
# (one nibble, plus checksum/sig rebuild) inside classes.dex of
# /system/framework/org.lineageos.platform.jar.  Fixing at postinstall
# time lets us stay on prebuilt upstream images while shipping a working
# uninstall path.
_patch_platform_jar_in_system_img() {
	local sysimg="${S}/system.img"
	local scratch="${T}/platform-patch"
	local jar_path="/system/framework/org.lineageos.platform.jar"

	mkdir -p "${scratch}" || die

	# debugfs -R always prints its own version banner ("debugfs 1.47.0
	# (...)" ) to stdout; a naive `... | grep -v ...` pipeline then makes
	# grep exit 1 whenever there is no additional output (which is the
	# successful case), silently reporting a spurious failure.  We instead
	# redirect debugfs chatter to a log and confirm success by checking
	# that the destination file was created and is non-empty.
	local dbg_log="${scratch}/debugfs.log"
	debugfs -R "dump ${jar_path} ${scratch}/orig.jar" "${sysimg}" \
		>"${dbg_log}" 2>&1
	if [[ ! -s "${scratch}/orig.jar" ]]; then
		einfo "debugfs output was:"
		sed 's/^/  /' "${dbg_log}"
		die "extracted jar is empty -- ${jar_path} missing or image layout changed?"
	fi

	local rc=0
	python3 "${FILESDIR}/patch_platform_jar.py" \
		"${scratch}/orig.jar" "${scratch}/fixed.jar" || rc=$?
	case "${rc}" in
		0) einfo "Waydroid platform.jar patched (removeApp mutability fix)." ;;
		1) einfo "Waydroid platform.jar already carries the fix; skipping." ;;
		*) die "patch_platform_jar.py failed with exit ${rc}" ;;
	esac

	# Reinsert the patched jar and invalidate the AOT sidecars.  ART will
	# fall back to interpreted mode for this jar on first boot; that path
	# is only exercised by uninstall (not hot code), so the cost is fine.
	# Skipping this deletion would keep ART loading the stale odex/vdex
	# whose baked-in vdex hash points at the pre-patch classes.dex, and
	# the fix silently wouldn't take effect.
	debugfs -w -f - "${sysimg}" <<-EOF >>"${dbg_log}" 2>&1 || die "debugfs write failed"
		cd /system/framework
		rm org.lineageos.platform.jar
		write ${scratch}/fixed.jar org.lineageos.platform.jar
		cd oat/x86_64
		rm org.lineageos.platform.odex
		rm org.lineageos.platform.vdex
	EOF

	# Sanity-check: pull the file back out and diff against what we wrote.
	debugfs -R "dump ${jar_path} ${scratch}/roundtrip.jar" "${sysimg}" \
		>>"${dbg_log}" 2>&1
	if [[ ! -s "${scratch}/roundtrip.jar" ]]; then
		die "post-write dump produced empty file"
	fi
	cmp -s "${scratch}/roundtrip.jar" "${scratch}/fixed.jar" \
		|| die "roundtrip mismatch -- system.img may be corrupted"
}

# The credits page text in chromiumos-overlay/licenses/LineageOS-waydroid-images
# is generated from these two files.  Pin their checksums so that an image
# uprev cannot silently ship notices that no longer describe the images.
#
# To regenerate that text after an image uprev: extract both NOTICE.xml.gz
# with debugfs and rebuild the licenses file from them.  The checksums below
# are verified at build time and the build fails if they no longer match.
# (This note lives here rather than in the licenses file itself: that file
# ships to users as part of chrome://os-credits, so it carries license
# information only, not build instructions.)
SYSTEM_NOTICE_MD5="b21236ec86c4188856bd7d0b5c8244d0"
VENDOR_NOTICE_MD5="a608a44ab5ee64e2fb5b0ca54e9eb699"

_extract_notices() {
	local out="${T}/notice"
	mkdir -p "${out}" || die

	debugfs -R "dump /system/etc/NOTICE.xml.gz ${out}/system-NOTICE.xml.gz" \
		"${S}/system.img" >/dev/null 2>&1
	debugfs -R "dump /etc/NOTICE.xml.gz ${out}/vendor-NOTICE.xml.gz" \
		"${S}/vendor.img" >/dev/null 2>&1

	local img want got
	for img in system vendor; do
		[[ -s ${out}/${img}-NOTICE.xml.gz ]] \
			|| die "no NOTICE.xml.gz inside ${img}.img -- image layout changed?"
		if [[ ${img} == system ]]; then
			want="${SYSTEM_NOTICE_MD5}"
		else
			want="${VENDOR_NOTICE_MD5}"
		fi
		got=$(md5sum < "${out}/${img}-NOTICE.xml.gz") || die
		got=${got%% *}
		if [[ ${got} != "${want}" ]]; then
			eerror "${img}.img NOTICE.xml.gz is ${got}, expected ${want}."
			eerror "The images changed, so the notices published on the"
			eerror "credits page no longer describe what we ship."
			eerror "Regenerate chromiumos-overlay/licenses/"
			eerror "LineageOS-waydroid-images from the new files and update"
			eerror "the checksums above."
			die "stale license notices for ${img}.img"
		fi
	done
}

src_unpack() {
	unzip -j "${DISTDIR}/waydroid-system-20260403.zip" "*.img" -d "${S}" || die
	unzip -j "${DISTDIR}/waydroid-vendor-20260428.zip" "*.img" -d "${S}" || die
}

src_prepare() {
	default
	_patch_platform_jar_in_system_img
	# After the edit: the notices must still be the ones we published.
	_extract_notices
}

src_install() {
	# Install under /build/share so that INSTALL_MASK excludes these large
	# images from the rootfs image (which is 2 GB and cannot fit them).
	# board_finalize_base_image copies them to the stateful partition instead.
	insinto /build/share/waydroid-extra/images
	doins "${S}"/system.img
	doins "${S}"/vendor.img

	# The unmodified notice files, so the text reproduced on the credits
	# page can be checked against what actually ships.  ~900 KiB total.
	insinto /usr/share/waydroid-extra/NOTICE
	doins "${T}"/notice/system-NOTICE.xml.gz
	doins "${T}"/notice/vendor-NOTICE.xml.gz
}
