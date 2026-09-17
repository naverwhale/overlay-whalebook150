# Copyright 2026 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
# CMake toolchain file for Android-T x86_64 using ChromeOS arc-toolchain-t.
#
# Replaces the Android NDK toolchain file used by the standalone build.sh.
# The arc-toolchain-t package installs everything under /opt/android-t/:
#   arc-llvm/14.0.5/bin/clang  — clang with Android libc (bionic) target
#   amd64/usr/include/         — Android-T system headers
#   amd64/usr/lib64/           — liblog.so, libcutils.so link stubs

set(CMAKE_SYSTEM_NAME Linux)   # "Android" without NDK causes cmake errors
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(_ARC_LLVM "/opt/android-t/arc-llvm/14.0.5")
set(_ARC_SYSROOT "/opt/android-t/amd64")

set(CMAKE_C_COMPILER   "${_ARC_LLVM}/bin/clang"   CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${_ARC_LLVM}/bin/clang++" CACHE FILEPATH "" FORCE)

# --target selects bionic libc (defines __ANDROID__, __BIONIC__) and
# sets Android API 33.  -fuse-ld=lld uses the bundled LLD linker.
set(_COMMON_FLAGS "--target=x86_64-linux-android33 -fuse-ld=lld -B${_ARC_LLVM}/bin")

set(CMAKE_C_FLAGS_INIT   "${_COMMON_FLAGS}" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "${_COMMON_FLAGS} -B${_ARC_SYSROOT}/usr/lib64 -L${_ARC_SYSROOT}/usr/lib64" CACHE STRING "" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS_INIT
    "${_COMMON_FLAGS} -B${_ARC_SYSROOT}/usr/lib64 -L${_ARC_SYSROOT}/usr/lib64" CACHE STRING "" FORCE)

# Tell cmake where to search for libraries/headers at build time.
set(CMAKE_FIND_ROOT_PATH "${_ARC_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# CMake's compiler test builds an executable, which requires Android bionic
# CRT objects (crtbegin_dynamic.o, crtend_android.o) that are not in the
# standard search path.  We only build shared libraries, so test with a
# static library to avoid the CRT link step entirely.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
