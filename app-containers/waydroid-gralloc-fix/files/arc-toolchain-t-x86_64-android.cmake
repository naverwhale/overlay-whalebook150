# Copyright (c) 2026 NAVER Corp.  All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
# See files/LICENSE.wrapper for the full text.
#
# CMake toolchain file for 64-bit Android-T (x86_64) using ChromeOS arc-toolchain-t.
#
# Used by the ebuild's src_compile() for the 64-bit half of the build.
# Required because the container's graphics allocator service runs as a
# 64-bit process and loads /vendor/lib64/libminigbm_gralloc_gbm_mesa.so;
# our 32-bit override alone would leave the allocator's buffer creation
# path unfixed (handle would still carry zero strides for spoofed YUV
# formats, even if the camera HAL side worked).

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(ARC_LLVM_DIR "/opt/android-t/arc-llvm/14.0.5" CACHE PATH "arc-llvm-14 install path")
set(ANDROID_T_SYSROOT "/opt/android-t/amd64" CACHE PATH "Android-T sysroot (header + i386/x86_64 stubs)")
set(ANDROID_T_LIBSUBDIR "lib64" CACHE STRING "Which lib subdir under sysroot/usr to use for linking")

set(CMAKE_C_COMPILER   "${ARC_LLVM_DIR}/bin/clang"   CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${ARC_LLVM_DIR}/bin/clang++" CACHE FILEPATH "" FORCE)

set(_COMMON_FLAGS "--target=x86_64-linux-android33 -fuse-ld=lld -B${ARC_LLVM_DIR}/bin")

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

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
