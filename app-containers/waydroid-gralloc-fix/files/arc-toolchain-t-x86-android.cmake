# Copyright (c) 2026 NAVER Corp.  All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
# See files/LICENSE.wrapper for the full text.
#
# CMake toolchain file for 32-bit Android-T (i686) using ChromeOS arc-toolchain-t.
#
# Used by the ebuild's src_compile() for the 32-bit half of the build.
# The 32-bit ABI is required because the Waydroid Android container's
# external camera HAL, the matching mapper@4.0-impl, and the
# /vendor/lib/libminigbm_gralloc_gbm_mesa.so it dlopens are all 32-bit.
# We must produce a 32-bit .so so the mapper can dlopen it as a drop-in
# replacement.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86)

set(ARC_LLVM_DIR "/opt/android-t/arc-llvm/14.0.5" CACHE PATH "arc-llvm-14 install path")
set(ANDROID_T_SYSROOT "/opt/android-t/amd64" CACHE PATH "Android-T sysroot (header + i386/x86_64 stubs)")
# arc-toolchain-t names the 32-bit i386 stub directory simply "lib" inside
# the amd64 sysroot (an ARC convention).
set(ANDROID_T_LIBSUBDIR "lib" CACHE STRING "Which lib subdir under sysroot/usr to use for linking")

set(CMAKE_C_COMPILER   "${ARC_LLVM_DIR}/bin/clang"   CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${ARC_LLVM_DIR}/bin/clang++" CACHE FILEPATH "" FORCE)

# --target picks bionic libc (defines __ANDROID__/__BIONIC__) and Android
# API 33.  -m32 is implied by the triple but pass it explicitly so any
# sub-build helpers that miss the triple still produce 32-bit.
set(_COMMON_FLAGS "--target=i686-linux-android33 -m32 -fuse-ld=lld -B${ARC_LLVM_DIR}/bin")

set(CMAKE_C_FLAGS_INIT   "${_COMMON_FLAGS}" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_INIT "${_COMMON_FLAGS}" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "${_COMMON_FLAGS} -B${ANDROID_T_SYSROOT}/usr/${ANDROID_T_LIBSUBDIR} -L${ANDROID_T_SYSROOT}/usr/${ANDROID_T_LIBSUBDIR}" CACHE STRING "" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS_INIT
    "${_COMMON_FLAGS} -B${ANDROID_T_SYSROOT}/usr/${ANDROID_T_LIBSUBDIR} -L${ANDROID_T_SYSROOT}/usr/${ANDROID_T_LIBSUBDIR}" CACHE STRING "" FORCE)

set(CMAKE_FIND_ROOT_PATH "${ANDROID_T_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# CMake's compiler test builds an executable, which requires Android bionic
# CRT objects (crtbegin_dynamic.o, crtend_android.o) that are not on the
# default search path; we only build shared libraries, so test with a
# static library to avoid the CRT link step entirely.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
