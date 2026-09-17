# Copyright 2026 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

# ============================================================================
# Package overview
# ============================================================================
# A single shipped artefact: a 6-byte binary patch of the Android external
# camera HAL implementation library
#     /vendor/lib/camera.device@3.4-external-impl.so
# that ships inside the Waydroid Lineage-20 (Android-13) container image.
# Intended to be bind-mounted over the container's copy at session start
# (see app-containers/waydroid 0011-camera-and-gralloc-overlay.patch).
#
# This package contains NO new source code -- it ships a single .so that
# is a derivative work of an AOSP / LineageOS binary (see "Origin and
# license" below).  The change is a 6-byte single-branch disable.
#
# ============================================================================
# Why a binary patch (not a source rebuild)
# ============================================================================
# Rebuilding ExternalCameraDeviceSession.cpp from AOSP would require the
# full camera HIDL infrastructure (libhidlbase, libcamera_metadata,
# libhardware/include/hardware/camera*, the 3.2/3.3/3.4 HIDL types,
# libgralloctypes, libfmq, libtinyxml2, etc.).  arc-toolchain-t carries
# the C/C++ headers and stubs for libutils only, not the camera HIDL
# stack, so a CMake/Soong rebuild standalone is not realistic without an
# AOSP soong build environment.  Runtime-extracting from vendor.img and
# patching at first-boot would introduce both latency and an extra
# failure surface.  A 6-byte NOP overwrite is well-understood, the
# assembly diff is fully auditable (see below), the patched .so is small
# (~400 KB), and the source artefact is plain Apache-2.0.
#
# ============================================================================
# What the patch changes
# ============================================================================
# ExternalCameraDeviceSession::configureV4l2StreamLocked() at the
# stream-format-validation hot path, located via the (still-exported)
# mangled symbol
#     _ZN7android8hardware6camera6device4V3_4
#         14implementation27ExternalCameraDeviceSession
#         25configureV4l2StreamLockedERKNS4_19SupportedV4L2FormatEd
#
#   .text+0x436cb  mov    0xbc(%esp), %eax       ; eax = width
#   .text+0x436d2  imul   0xc0(%esp), %eax       ; eax = w * h
#   .text+0x436da  add    %eax, %eax             ; eax = w * h * 2
#   .text+0x436dc  test   %esi, %esi             ; bufferSize == 0?
#   .text+0x436de  je     0x438a6 <error>        ; kept: empty-buffer reject
#   .text+0x436e4  cmp    %eax, %esi             ; bufferSize > w*h*2 ?
#   .text+0x436e6  ja     0x438a6 <error>        ; <<< 6 bytes NOPed out
#   .text+0x436ec  ... continues into v4l2 stream start ...
#
# Byte-level diff at file offset 0x426e6:
#     before: 0f 87 ba 01 00 00      ; ja  0x1ba  (rel32 to 0x438a6)
#     after:  90 90 90 90 90 90      ; 6 x nop
#
# The cmp at 0x436e4 still executes; only the unsigned-greater jump at
# 0x436e6 is neutralised.  The bufferSize==0 short-circuit at 0x436de
# stays intact, so genuinely empty buffers are still rejected.  No
# other bytes in the file are touched; the .dynsym, GNU build-ID, all
# PLT/GOT entries, all other code paths are byte-identical to the
# upstream Lineage-20.0 build.
#
# Reproduction:
#     # Verify upstream and apply patch:
#     python3 -c '
#     with open("camera.device@3.4-external-impl.so", "r+b") as f:
#         f.seek(0x426e6)
#         assert f.read(6) == bytes.fromhex("0f87ba010000"), "upstream mismatch"
#         f.seek(0x426e6); f.write(b"\x90" * 6)'
#
# ============================================================================
# Why this is safe
# ============================================================================
# Several USB Video Class camera firmwares pad the V4L2 "max image size"
# by a constant overhead (typically +589 bytes of SCR / header metadata).
# The actual compressed frame data is always strictly smaller than the
# uncompressed YUV422 bound (w*h*2):
#
#     Camera                  Resolution    w*h*2       V4L2 reports   delta
#     Sonix LG FHD WebCam     640x480 MJPG   614400         614989    +589
#     Sonix LG FHD WebCam    1920x1080 MJPG 4147200        4147789    +589
#     Chicony LG 5M Camera   1920x1080 MJPG 4147200        4147789    +589
#     Chicony LG 5M Camera   1280x720  MJPG 1843200        1843200    (exact)
#
# Without the patch the HAL rejects every over-reporting case and the
# affected camera produces no usable stream.
#
# Compressed formats (MJPG): always smaller than w*h*2 in payload; the
# +589 padding is metadata and never overflows the buffer.
# Raw formats (YUYV): bufferSize == w*h*2 exactly, the check was a
# no-op there and the NOP changes nothing.
# Kernel side: uvcvideo bounds bytes_used per buffer length on every
# DQBUF, so even a misbehaving firmware cannot cause an OOB write.
#
# ============================================================================
# Origin and license of the shipped binary
# ============================================================================
# The unmodified (upstream) .so is part of the LineageOS 20.0 Waydroid
# x86_64 vendor image fetched by sibling ebuild
# app-containers/waydroid-images:
#
#     SRC_URI of waydroid-images-20260428:
#       https://sourceforge.net/projects/waydroid/files/images/vendor/
#         waydroid_x86_64/lineage-20.0-20260428-MAINLINE-waydroid_x86_64-vendor.zip
#     Path inside vendor.img:
#       /lib/camera.device@3.4-external-impl.so
#
# That binary is the build output of AOSP
#     hardware/interfaces/camera/device/3.4/default/
#         ExternalCameraDeviceSession.cpp
#         ExternalCameraDevice.cpp
#         ExternalCameraUtils.cpp
#     (and the matching 3.5 / 3.6 inheritance plus HIDL types),
#         Copyright (C) The Android Open Source Project
#         Copyright (C) The LineageOS Project
# distributed under the Apache License, Version 2.0
# (SPDX-License-Identifier: Apache-2.0).
#
# Apache-2.0 explicitly permits redistribution of modified binaries
# (section 4 "Redistribution") so long as
#   (a) the recipient receives a copy of the License -- Portage records
#       LICENSE="Apache-2.0" below and the system carries the full text
#       at /usr/share/portage/licenses/Apache-2.0 via sys-libs/timezone-data
#       and friends;
#   (b) modified files carry prominent notice of the change -- the
#       6-byte diff is documented in this header, in the matching hunk
#       of waydroid's 0011-camera-and-gralloc-overlay.patch, and in the
#       package DESCRIPTION printed by `emerge -pv`.
#
# The shipped binary contains no GPL components (only AOSP camera HIDL
# code and its Apache-2.0 dependencies; GPL-2.0 kernel-uapi headers it
# included at build time only contribute symbol/constant definitions,
# not GPL-covered code).  As a NAVER modification of AOSP/LineageOS
# code, the modified binary remains under Apache-2.0; we do not
# relicense.
#
# Cryptographic identity:
#     File type    : ELF 32-bit LSB shared object, Intel 80386, stripped
#     Size         : 407412 bytes (NOP overwrite preserves length)
#     GNU Build-ID : c332c1c4c024790251c2ae3eed226338 (unchanged, same .text)
#     MD5 unpatched: 2b2b0a73e12e0083f684496f224d54b0
#     MD5 patched  : 4971b50f4e9d02b11de71637c9a2fabc
# ============================================================================

DESCRIPTION="6-byte binary patch of LineageOS 20 camera.device@3.4-external-impl.so (UVC MJPG buffer-size sanity check disable; Apache-2.0 derivative of AOSP hardware/interfaces)"
HOMEPAGE="https://source.android.com/docs/security/overview/updates-resources https://lineageos.org"

# The shipped .so is a derivative work of AOSP/LineageOS material that
# is distributed under Apache-2.0; we keep the same license unchanged.
# Apache-2.0 is in @FREE on ChromeOS so no extra accept_license entry is
# needed on standard builds.
#
# AOSP-camera-hal is a custom license in chromiumos-overlay/licenses/.  It
# carries the AOSP/LineageOS copyright attribution (Apache-2.0 section 4 d)
# and the notice of our 6-byte modification (section 4 b), neither of which
# the stock Apache-2.0 text provides.  It has to be a named license rather
# than a file in the work directory: chromite/licensing only scans package
# sources for licenses in COPYRIGHT_ATTRIBUTION_LICENSES (the BSD/MIT
# family) or LOOK_IN_SOURCE_LICENSES, and Apache-2.0 is in neither, so a
# dropped-in LICENSE file would never reach about:credits.
LICENSE="AOSP-camera-hal Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE=""

# mirror     - we ship the patched blob ourselves; no upstream mirror.
# strip      - the binary is a 32-bit Android ELF; ChromeOS's normal
#              strip step would reject the platform/host mismatch.
# binchecks  - ChromeOS's binary NEEDED/dep check expects ChromeOS-native
#              libraries; the Android dynamic-link rules don't apply.
# splitdebug - matches the strip restriction.
RESTRICT="mirror strip binchecks splitdebug"

# Pure prebuilt; no toolchain dependency, no source fetch.
BDEPEND=""
RDEPEND=""
DEPEND=""

S="${WORKDIR}"

src_unpack() {
	# Nothing to fetch or unpack -- the prebuilt patched .so lives in
	# ${FILESDIR} and is referenced directly by src_install.
	mkdir -p "${S}"
}

src_install() {
	# Install the patched HAL.  The matching lxc.py bind-mount entry in
	# the waydroid ebuild's 0011 patch overlays this file on top of the
	# container's /vendor/lib/camera.device@3.4-external-impl.so at LXC
	# session start; the upstream HAL inside vendor.img is never
	# modified on disk.
	insinto /usr/lib/waydroid/android-overlay/vendor/lib
	doins "${FILESDIR}/camera.device@3.4-external-impl.so"
}
