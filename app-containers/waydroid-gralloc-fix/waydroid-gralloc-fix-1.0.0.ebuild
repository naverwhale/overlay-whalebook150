# Copyright 2026 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

# ----------------------------------------------------------------------------
# What this package does and why
# ----------------------------------------------------------------------------
# WhaleOS's Waydroid container ships a 32-bit + 64-bit gralloc stack from
# the upstream Waydroid Android image:
#     /vendor/lib{,64}/libminigbm_gralloc_gbm_mesa.so
#     /vendor/lib{,64}/hw/android.hardware.graphics.mapper@4.0-impl.minigbm_gbm_mesa.so
#     /vendor/bin/hw/android.hardware.graphics.allocator@4.0-service.minigbm_gbm_mesa
#
# The gbm_mesa minigbm backend cannot allocate multi-planar YUV formats
# (NV12, NV21, FLEX_YCbCr_420_888 etc.) through mesa-libgbm directly and
# falls back to a "spoofed" R8 1D allocation that is later reshaped into a
# 4096-wide R8 2D texture.  But the same reshape is NOT applied on the
# import side or on the map side, so when the external camera HAL imports
# the buffer in another process and locks it for YCbCr access, mesa-libgbm
# refuses to map the buffer and the HAL receives y=cb=cr=0x0.
#
# This package rebuilds libminigbm_gralloc_gbm_mesa.so for both 32-bit and
# 64-bit with two small fixes:
#
#   0001-cros_gralloc-plane-stride-offset-fallback.patch
#       cros_gralloc_driver::allocate() recomputes any zero stride/offset
#       from the resolved format + width after the per-plane loop, so the
#       handle always carries a valid planar layout for the client.
#
#   0002-gbm_mesa-reshape-spoofed-format-on-import-and-map.patch
#       gbm_mesa_bo_import() applies the same 4096 x ceil(size/4096) R8 2D
#       reshape as gbm_mesa_bo_create(), passes the R8 stride to libgbm,
#       and saves it into priv->map_stride.  gbm_mesa_bo_map() uses that
#       stride to map the texture in its native shape, restoring valid
#       y/cb/cr pointers in mapper@4.0-impl's lockYCbCr().
#
# The HIDL mapper/allocator binaries are kept as shipped; they
# dlopen-resolve cros_gralloc_driver symbols out of the libraries we
# rebuild here, so a single .so override per ABI is sufficient.
#
# The two .so files are installed under android-overlay/vendor/lib{,64}/
# so that the lxc.py bind-mount logic (waydroid 0011 patch) overlays them
# on top of the container's /vendor/lib{,64}/libminigbm_gralloc_gbm_mesa.so
# when the session starts.
#
# ----------------------------------------------------------------------------
# Source provenance
# ----------------------------------------------------------------------------
# The Waydroid Lineage-20 image pulls minigbm not from AOSP but from a
# Waydroid fork that adds a `gbm_mesa_driver/` backend (mesa-libgbm wrapper
# used because the container has no DRM master access on ChromeOS).  The
# Waydroid local manifest at
#   https://raw.githubusercontent.com/waydroid/android_vendor_waydroid/
#       lineage-20/manifest_scripts/manifests-33/02-waydroid.xml
# has:
#   <remove-project name="platform/external/minigbm" />
#   <project path="external/minigbm"
#            name="WayDroid/android_external_minigbm"
#            remote="ghub" revision="refs/heads/lineage-18.1"/>
#
# We fetch a tarball snapshot of that branch.  Using AOSP minigbm or the
# ChromeOS platform/minigbm tree would diverge in ABI (different
# cros_gralloc_driver class layout, no gbm_mesa_driver/) and would not
# match the mapper@4.0-impl.minigbm_gbm_mesa.so already in the container.
#
# libdrm header dependency (xf86drm.h, xf86drmMode.h) is also taken from a
# Waydroid fork because arc-toolchain-t does not bundle these userspace
# headers.  Same manifest, lineage-18.1 branch:
#   <project path="external/libdrm" name="WayDroid/android_external_libdrm"
#            remote="ghub" revision="refs/heads/lineage-18.1"/>
# ----------------------------------------------------------------------------

DESCRIPTION="32-bit+64-bit libminigbm_gralloc_gbm_mesa.so override for Waydroid camera (NV12/spoofed-format reshape fix)"
# Two upstream sources:
#   * https://github.com/WayDroid/android_external_minigbm (the main tree we
#     build; carries LICENSE + Android.bp license_kinds for
#     Apache-2.0 / BSD / MIT).
#   * https://github.com/WayDroid/android_external_libdrm (build-time header
#     reference only; runtime libdrm is the container's vendor libdrm.so and
#     the host side is x11-libs/libdrm which has its own chromiumos entry).
# Wrapper files (this ebuild's own patches, CMakeLists.txt, toolchain
# cmake files) are BSD-3-Clause -- see files/LICENSE.wrapper.
HOMEPAGE="https://github.com/WayDroid/android_external_minigbm"

# We ship the upstream source tarballs inside files/ (see
# files/waydroid-minigbm-*.tar.gz, files/waydroid-libdrm-*.tar.gz)
# rather than fetching them from codeload.  The concrete failure
# that led here was:
#   * SRC_URI pointed at codeload's `refs/heads/lineage-18.1` URL,
#     which follows the upstream branch head.  An unrelated push
#     upstream shifted what codeload returned and the Manifest
#     check failed with "Filesize does not match recorded size".
# Pinning SRC_URI to a specific commit SHA fixes that specific
# regression on its own.  GitHub also warns that autogenerated
# archives are not guaranteed byte-stable long-term (github.blog,
# 2023-02-21, "Update on the future stability of source code
# archives and hashes"), which we have to trust the mirror against
# whether we pin the branch or the SHA.  Given both together, and
# given how narrow this package's use is right now (one board,
# still gated behind the LG14U390 experiment), we commit the
# exact bytes we build against next to the ebuild -- a full
# distfiles mirror is the right long-term home and is captured
# as a follow-up.  See files/README for the audit procedure that
# proves the committed tarballs match the pinned SHAs.
#
# Refresh procedure (only when we actually need a new upstream drop):
#   git clone https://github.com/WayDroid/android_external_minigbm && \
#     cd android_external_minigbm && \
#     git archive --format=tar.gz --prefix=android_external_minigbm-<SHA>/ \
#         <SHA> > waydroid-minigbm-<short-sha>.tar.gz
# and drop the result into files/ (short-sha in the filename is
# just for humans; ${MINIGBM_COMMIT} below is what actually gates
# the code path).
#
# Pinned one commit behind lineage-18.1 HEAD.  The current HEAD
# ("Fix YVU420 format") touches gbm_mesa_driver/gbm_mesa_internals.cpp
# and conflicts with our
# 0002-gbm_mesa-reshape-spoofed-format-on-import-and-map patch.  Bump
# forward only after that patch is rebased against upstream.
MINIGBM_COMMIT="16844babfbd83d7c206ca22256257cbf26ca7de1"
LIBDRM_COMMIT="6bfcfc725fbe0ece0918535556d61ee567b1ffff"
SRC_URI=""

# Upstream license is the mixed Apache-2.0 / BSD / MIT set defined as
# external_minigbm_license in the original Android.bp.
LICENSE="Apache-2.0 BSD MIT"
SLOT="0"
KEYWORDS="*"
IUSE=""

# mirror   - no upstream tarball on a Gentoo mirror.
# binchecks - the produced .so has no NEEDED entries for libdrm/libcutils/
#             liblog/libnativewindow/libsync; they are resolved by the
#             loading process (mapper@4.0-impl or allocator service) at
#             runtime inside the container.  Same pattern as the audio HAL.
RESTRICT="mirror binchecks"

# arc-toolchain-t provides:
#   /opt/android-t/arc-llvm/14.0.5/bin/clang  (Android-T LLVM 14)
#   /opt/android-t/amd64/usr/include/         (cutils/, hardware/, drm/, system/, ui/, ...)
#   /opt/android-t/amd64/usr/lib/             32-bit i386 .so stubs (despite the "amd64" dir)
#   /opt/android-t/amd64/usr/lib64/           64-bit x86_64 .so stubs
BDEPEND="sys-devel/arc-toolchain-t
	dev-util/cmake
	sys-fs/e2tools"

# We do not RDEPEND on waydroid-images (the runtime container's own
# libdrm.so is what actually resolves symbols at session start), but we
# DO need vendor.img at build time so we can extract libdrm.so as a link
# target with matching ABI to the container's loader.  waydroid-images
# installs vendor.img to ${SYSROOT}/build/share/waydroid-extra/images/.
RDEPEND=""
DEPEND="app-containers/waydroid-images"

# Both tarballs were produced with `git archive --prefix=<repo>-<sha>/`,
# so unpacking them yields ${WORKDIR}/android_external_{minigbm,libdrm}-<sha>/.
S="${WORKDIR}/android_external_minigbm-${MINIGBM_COMMIT}"

src_unpack() {
	# SRC_URI is empty; the two tarballs live in files/ next to this
	# ebuild.  See the block near MINIGBM_COMMIT for the rationale.
	local minigbm_tar="${FILESDIR}/waydroid-minigbm-${MINIGBM_COMMIT:0:7}.tar.gz"
	local libdrm_tar="${FILESDIR}/waydroid-libdrm-${LIBDRM_COMMIT:0:7}.tar.gz"
	unpack "${minigbm_tar}"
	unpack "${libdrm_tar}"

	# Surface the wrapper LICENSE at the workdir top-level so chromite's
	# licenses_lib.py picks it up alongside the upstream LICENSE inside
	# the minigbm tarball.  Otherwise the "Scanned Source License" list
	# would only contain the minigbm entry and our BSD-3-Clause wrapper
	# would go undocumented in about:credits.
	cp "${FILESDIR}/LICENSE.wrapper" "${WORKDIR}/LICENSE.wrapper" \
		|| die "failed to stage wrapper LICENSE"

	# Sibling libdrm tarball provides xf86drm.h / xf86drmMode.h headers used
	# by minigbm but not bundled with arc-toolchain-t.
	mv "${WORKDIR}/android_external_libdrm-${LIBDRM_COMMIT}" "${WORKDIR}/libdrm" \
		|| die "libdrm rename failed"

	# Extract libdrm.so (both ABIs) from the container's vendor.img so
	# we have something to link against at build time.  Symbols are
	# resolved at runtime by the container's own loader, so we only
	# need the .so as a name reference for ld.  e2cp reads ext4 without
	# mount privileges -- the build phase has none.
	local vendor_img="${SYSROOT}/build/share/waydroid-extra/images/vendor.img"
	[ -f "${vendor_img}" ] || die "missing ${vendor_img} (is waydroid-images installed?)"

	mkdir -p "${WORKDIR}/drm-stubs/lib" "${WORKDIR}/drm-stubs/lib64"
	e2cp "${vendor_img}:/lib/libdrm.so"   "${WORKDIR}/drm-stubs/lib/libdrm.so" \
		|| die "failed to extract 32-bit libdrm.so from vendor.img"
	e2cp "${vendor_img}:/lib64/libdrm.so" "${WORKDIR}/drm-stubs/lib64/libdrm.so" \
		|| die "failed to extract 64-bit libdrm.so from vendor.img"
}

src_prepare() {
	default
	# Apply both source-level fixes.  See header comments in each patch
	# file for the exact behaviour change and why it matters.
	eapply "${FILESDIR}/0001-cros_gralloc-plane-stride-offset-fallback.patch"
	eapply "${FILESDIR}/0002-gbm_mesa-reshape-spoofed-format-on-import-and-map.patch"

	# Drop in our CMakeLists + toolchain files.  The upstream Android.bp
	# is intentionally not used because soong/full-AOSP build env is not
	# available in the ChromeOS chroot.
	cp "${FILESDIR}/CMakeLists.txt" "${S}/CMakeLists.txt"
	cp "${FILESDIR}/arc-toolchain-t-x86-android.cmake" "${S}/"
	cp "${FILESDIR}/arc-toolchain-t-x86_64-android.cmake" "${S}/"
}

src_compile() {
	local LIBDRM_DIR="${WORKDIR}/libdrm"

	# 32-bit i686 build (for the camera HAL and other 32-bit clients).
	local build32="${WORKDIR}/build32"
	mkdir -p "${build32}"
	cmake -S "${S}" -B "${build32}" \
		-DCMAKE_TOOLCHAIN_FILE="${S}/arc-toolchain-t-x86-android.cmake" \
		-DLIBDRM_SOURCE_DIR="${LIBDRM_DIR}" \
		-DLIBDRM_LINK_DIR="${WORKDIR}/drm-stubs/lib" \
		-DCMAKE_BUILD_TYPE=Release \
		|| die "cmake configure (32-bit) failed"
	cmake --build "${build32}" -- -j"$(nproc)" \
		|| die "cmake build (32-bit) failed"

	# 64-bit x86_64 build (for the allocator service and 64-bit clients).
	local build64="${WORKDIR}/build64"
	mkdir -p "${build64}"
	cmake -S "${S}" -B "${build64}" \
		-DCMAKE_TOOLCHAIN_FILE="${S}/arc-toolchain-t-x86_64-android.cmake" \
		-DLIBDRM_SOURCE_DIR="${LIBDRM_DIR}" \
		-DLIBDRM_LINK_DIR="${WORKDIR}/drm-stubs/lib64" \
		-DCMAKE_BUILD_TYPE=Release \
		|| die "cmake configure (64-bit) failed"
	cmake --build "${build64}" -- -j"$(nproc)" \
		|| die "cmake build (64-bit) failed"
}

src_install() {
	# CMakeLists.txt builds the target as `minigbm` with OUTPUT_NAME set
	# to `minigbm_gralloc_gbm_mesa`, so the actual artefact filename is
	# libminigbm_gralloc_gbm_mesa.so -- exactly what the container's
	# mapper@4.0-impl.minigbm_gbm_mesa.so dlopens.  Install to
	# android-overlay/vendor/lib{,64}/.  The waydroid 0011 patch's
	# lxc.py bind-mount entries pick the matching ABI's .so up at
	# session start and overlay it on top of the container's
	# /vendor/lib{,64}/libminigbm_gralloc_gbm_mesa.so.
	insinto /usr/lib/waydroid/android-overlay/vendor/lib
	doins "${WORKDIR}/build32/libminigbm_gralloc_gbm_mesa.so"

	insinto /usr/lib/waydroid/android-overlay/vendor/lib64
	doins "${WORKDIR}/build64/libminigbm_gralloc_gbm_mesa.so"
}
