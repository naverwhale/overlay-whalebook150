# Copyright 2024 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="43d6564383ffc1de07f00c6332ca642b5699c216"
CROS_WORKON_TREE="0da6dbab174fcdefef11fb6af88d954126ffe171"
CROS_WORKON_PROJECT="chromiumos/third_party/adhd"
CROS_WORKON_LOCALNAME="adhd"

inherit cros-workon

DESCRIPTION="CRAS audio HAL for Waydroid (audio.primary.cras.so, Android API-33 x86_64)"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/overlays/chromiumos-overlay/"

# Apache-2.0     - the AOSP audio HAL interface headers this is built against.
# AOSP-audio-headers - custom license in chromiumos-overlay/licenses/ carrying
#                  the AOSP copyright attribution for those headers; stock
#                  Apache-2.0 has no attribution and chromite/licensing does
#                  not scan sources for Apache-2.0 packages.
# BSD            - the NAVER-authored sources in ${FILESDIR} (audio_cras_hal.c,
#                  compat.c, the CMake files and the tinyalsa stub).  BSD needs
#                  copyright attribution: the text ships as
#                  files/LICENSE.whaleos and src_unpack copies it to
#                  ${WORKDIR}/LICENSE.whaleos so that chromite's license scan
#                  finds it in any tree, including the public board overlay
#                  built against vanilla ChromiumOS.  It has to be src_unpack,
#                  not src_prepare: when license.json is missing from the vdb,
#                  `licenses --generate-licenses` (run by build_image) only
#                  runs `ebuild ... unpack` before scanning the work dir.
#                  This overlay also carries the same text as
#                  licenses/copyright-attribution/app-containers/
#                  waydroid-audio-hal, which chromite prefers when present;
#                  keep the two files identical.  Without either the scan
#                  would fall back to the LICENSE file of the adhd checkout
#                  in ${WORKDIR} and attribute our code to the ChromiumOS
#                  Authors.
# BSD-Google     - the CRAS client sources from third_party/adhd
#                  (cras_client.c, cras_util.c, ...) that CMakeLists.txt
#                  links into audio.primary.cras.so as a static library.
LICENSE="AOSP-audio-headers Apache-2.0 BSD BSD-Google"
SLOT="0"
KEYWORDS="*"
IUSE=""
# mirror: no upstream tarball to mirror.
# binchecks: libcutils.so and liblog.so are Android runtime libraries
# provided by the container image, not by any ChromeOS package.
RESTRICT="mirror binchecks"

# arc-toolchain-t provides:
#   /opt/android-t/arc-llvm/14.0.5/bin/clang  (Android-T LLVM 14)
#   /opt/android-t/amd64/usr/include/          (hardware/, cutils/, …)
#   /opt/android-t/amd64/usr/lib64/            (liblog.so, libcutils.so stubs)
BDEPEND="
	sys-devel/arc-toolchain-t
	dev-util/cmake
"

RDEPEND=""
DEPEND=""

src_unpack() {
	cros-workon_src_unpack
	# NAVER BSD attribution for the ${FILESDIR} sources, staged at the top
	# of the work dir where the chromite license scan looks (see the
	# LICENSE comment near the top).
	cp "${FILESDIR}/LICENSE.whaleos" "${WORKDIR}/LICENSE.whaleos" \
		|| die "failed to stage NAVER LICENSE"
}

src_prepare() {
	# Apply ADHD source patches into ${S} (the cros-workon adhd checkout)
	# before the static libcras library is compiled from those sources.
	eapply "${FILESDIR}/0001-cras-helper-use-direction-param.patch"

	# Copy audio HAL source files from FILESDIR into a writable build area.
	local hal_src="${WORKDIR}/hal-src"
	mkdir -p "${hal_src}/vendor/tinyalsa" "${hal_src}/vendor/system" || die
	cp "${FILESDIR}/audio_cras_hal.c" "${hal_src}/" || die
	cp "${FILESDIR}/compat.c" "${hal_src}/" || die
	cp "${FILESDIR}/CMakeLists.txt" "${hal_src}/" || die
	cp "${FILESDIR}/arc-toolchain-t-x86_64.cmake" "${hal_src}/" || die
	cp "${FILESDIR}/vendor/tinyalsa/asoundlib.h" "${hal_src}/vendor/tinyalsa/" || die
	cp "${FILESDIR}"/vendor/system/*.h "${hal_src}/vendor/system/" || die

	eapply_user
}

src_compile() {
	local hal_src="${WORKDIR}/hal-src"
	local build_dir="${WORKDIR}/hal-build"
	mkdir -p "${build_dir}"

	cmake -S "${hal_src}" -B "${build_dir}" \
		-DCMAKE_TOOLCHAIN_FILE="${hal_src}/arc-toolchain-t-x86_64.cmake" \
		-DADHD_ROOT="${S}" \
		-DANDROID_T_INC="/opt/android-t/amd64/usr/include" \
		-DCMAKE_BUILD_TYPE=Release \
		|| die "cmake configure failed"

	cmake --build "${build_dir}" -- -j"$(nproc)" \
		|| die "cmake build failed"
}

src_install() {
	# Install to /usr/lib/waydroid/android-overlay/system/lib64/hw/ so that
	# the waydroid-container.conf pre-start (which copies this directory to
	# overlay_rw) and the lxc.py CRAS bind-mount (0006 patch) can find it.
	#
	# NOTE: liblog.so and libcutils.so are Android runtime libraries provided
	# by the container image, not ChromeOS packages. The RESTRICT="binchecks"
	# above suppresses the missing-deps check for those symbols.
	insinto /usr/lib/waydroid/android-overlay/system/lib64/hw
	doins "${WORKDIR}/hal-build/audio.primary.cras.so"
}
