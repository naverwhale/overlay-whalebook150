# Copyright (c) 2026 NAVER Corp.  All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
# See files/LICENSE.wrapper for the full text.

cmake_minimum_required(VERSION 3.21)
project(libminigbm_gralloc_gbm_mesa C CXX)

# ----------------------------------------------------------------------------
# What this build produces
# ----------------------------------------------------------------------------
# A single shared library, libminigbm_gralloc_gbm_mesa.so, built once per
# target ABI (32-bit i686 and 64-bit x86_64) via two separate cmake
# invocations using the two arc-toolchain-t-* toolchain files.  The
# ebuild's src_compile() runs both back-to-back.
#
# The source tree is `WayDroid/android_external_minigbm @ lineage-18.1`
# (see the ebuild header for the manifest fragment that pins this branch).
# We deliberately do not use the upstream Android.bp, which would require
# a full AOSP soong build environment.  Instead this CMakeLists hand-picks
# the same source filegroups that the Soong target
# `libminigbm_gralloc_gbm_mesa` composes (gbm_mesa_driver/Android.bp):
#
#   minigbm_core_files            (top-level Android.bp)
#       amdgpu.c, drv.c, drv_array_helpers.c, drv_helpers.c, dumb_driver.c,
#       i915.c, mediatek.c, msm.c, rockchip.c, vc4.c,
#       virtgpu.c, virtgpu_cross_domain.c, virtgpu_virgl.c
#
#   minigbm_gralloc_common_files  (top-level Android.bp)
#       cros_gralloc/cros_gralloc_buffer.cc
#       cros_gralloc/cros_gralloc_helpers.cc
#       cros_gralloc/cros_gralloc_driver.cc   (patched by 0001-...)
#
#   gbm_mesa backend              (gbm_mesa_driver/Android.bp)
#       gbm_mesa_driver/gbm_mesa_internals.cpp  (patched by 0002-...)
#       gbm_mesa_driver/gbm_mesa_driver.cpp
#
# The cflag -DDRV_EXTERNAL is the same one the Soong target uses; it tells
# drv.c that the backend is provided externally (i.e. by libgbm_mesa).
# ----------------------------------------------------------------------------

# ANDROID_T_SYSROOT and LIBDRM_SOURCE_DIR come from the toolchain file /
# the ebuild's cmake -D flags.  They name:
#   - ANDROID_T_SYSROOT: /opt/android-t/<arch>  (Android-T headers + stubs)
#   - LIBDRM_SOURCE_DIR: ${WORKDIR}/libdrm      (xf86drm.h, xf86drmMode.h source)
if(NOT DEFINED ANDROID_T_SYSROOT)
    message(FATAL_ERROR "ANDROID_T_SYSROOT must be set by the toolchain file")
endif()
if(NOT DEFINED LIBDRM_SOURCE_DIR)
    message(FATAL_ERROR "LIBDRM_SOURCE_DIR must be passed in (e.g. -DLIBDRM_SOURCE_DIR=${WORKDIR}/libdrm)")
endif()

# Path layout under ANDROID_T_SYSROOT:
#   usr/include/ ........... shared C headers (cutils/, hardware/, drm/, ...)
#   usr/lib/   ............. 32-bit i386 .so stubs (despite the 'amd64' parent dir)
#   usr/lib64/ ............. 64-bit x86_64 .so stubs
set(ANDROID_INC "${ANDROID_T_SYSROOT}/usr/include")

# The toolchain file picks the right lib subdir (lib vs lib64) via
# ANDROID_T_LIBSUBDIR.
if(NOT DEFINED ANDROID_T_LIBSUBDIR)
    set(ANDROID_T_LIBSUBDIR "lib")  # default 32-bit
endif()
set(ANDROID_LIB "${ANDROID_T_SYSROOT}/usr/${ANDROID_T_LIBSUBDIR}")

# libstdc++ headers live with the clang toolchain itself; the toolchain
# file passes ARC_LLVM_DIR.
if(NOT DEFINED ARC_LLVM_DIR)
    message(FATAL_ERROR "ARC_LLVM_DIR must be set by the toolchain file")
endif()
set(ANDROID_CXX_INC "${ARC_LLVM_DIR}/include/c++/v1")

# ----------------------------------------------------------------------------
# Single library target
# ----------------------------------------------------------------------------
add_library(minigbm SHARED
    # minigbm_core_files
    amdgpu.c
    drv.c
    drv_array_helpers.c
    drv_helpers.c
    dumb_driver.c
    i915.c
    mediatek.c
    msm.c
    rockchip.c
    vc4.c
    virtgpu.c
    virtgpu_cross_domain.c
    virtgpu_virgl.c
    # minigbm_gralloc_common_files (cros_gralloc_driver.cc is patched)
    cros_gralloc/cros_gralloc_buffer.cc
    cros_gralloc/cros_gralloc_helpers.cc
    cros_gralloc/cros_gralloc_driver.cc
    # gbm_mesa backend (gbm_mesa_internals.cpp is patched)
    gbm_mesa_driver/gbm_mesa_internals.cpp
    gbm_mesa_driver/gbm_mesa_driver.cpp
)

# Output name must match what mapper@4.0-impl.minigbm_gbm_mesa.so dlopens.
set_target_properties(minigbm PROPERTIES
    PREFIX "lib"
    OUTPUT_NAME "minigbm_gralloc_gbm_mesa"
)

target_include_directories(minigbm PRIVATE
    ${ANDROID_INC}
    ${ANDROID_INC}/drm        # drm.h / drm_fourcc.h are nested under drm/
    ${LIBDRM_SOURCE_DIR}      # xf86drm.h, xf86drmMode.h (Waydroid libdrm fork)
    ${LIBDRM_SOURCE_DIR}/include/drm
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Mirror the Soong defaults from external_minigbm Android.bp.
target_compile_definitions(minigbm PRIVATE
    DRV_EXTERNAL
    _GNU_SOURCE=1
    _FILE_OFFSET_BITS=64
    ANDROID_API_LEVEL=33
)

target_compile_options(minigbm PRIVATE
    -include cassert                 # gbm_mesa_internals.cpp uses assert() but doesn't include it
    -isystem ${ANDROID_CXX_INC}      # libstdc++ headers from arc-llvm
    -fPIC
    -Wall
    -Wno-unused-parameter
    -Wno-unused-function
    -Wno-sign-compare
    -Wno-pointer-arith
    -Wno-cast-qual
    -Wno-cast-align
    --sysroot=${ANDROID_T_SYSROOT}   # block host /usr/include from leaking in (would pull host xf86drm.h)
)

set_source_files_properties(
    cros_gralloc/cros_gralloc_buffer.cc
    cros_gralloc/cros_gralloc_helpers.cc
    cros_gralloc/cros_gralloc_driver.cc
    gbm_mesa_driver/gbm_mesa_internals.cpp
    gbm_mesa_driver/gbm_mesa_driver.cpp
    PROPERTIES COMPILE_FLAGS "-std=c++17")

# Link against the Android-T stubs (libcutils, liblog, libnativewindow,
# libsync) shipped with arc-toolchain-t, plus libdrm.so that we extract
# from the Waydroid container's vendor.img at build time (see the
# ebuild's src_unpack -- arc-toolchain-t carries no libdrm stub).  At
# runtime the container's own loader resolves all of these.  See the
# audio HAL (waydroid-audio-hal) for the same pattern and the binchecks
# RESTRICT in the ebuild for why this is safe.
if(NOT DEFINED LIBDRM_LINK_DIR)
    message(FATAL_ERROR "LIBDRM_LINK_DIR must be passed in (directory containing libdrm.so extracted from vendor.img)")
endif()

target_link_directories(minigbm PRIVATE
    ${ANDROID_LIB}
    ${LIBDRM_LINK_DIR}
)
target_link_libraries(minigbm PRIVATE
    cutils
    log
    nativewindow
    sync
    drm
)
target_link_options(minigbm PRIVATE
    -Wl,--allow-shlib-undefined
    -Wl,--unresolved-symbols=ignore-in-shared-libs
    --sysroot=${ANDROID_T_SYSROOT}
)
