# Copyright 2026 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
cmake_minimum_required(VERSION 3.21)
project(audio_cras_hal C)

# liblog and libcutils are Android runtime libraries that are already loaded
# into the audioserver process before this HAL is dlopen'd. They are NOT linked
# explicitly here to avoid NEEDED entries that would fail ChromeOS dep_check
# (no ChromeOS package owns them). Symbols are resolved at runtime via the
# global symbol table of the loading process.

# All three paths can be overridden on the cmake command line.
# Defaults work for the standalone build.sh (audio-hal/) workflow;
# the ebuild passes explicit values at emerge time.
set(ADHD_ROOT
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../adhd"
    CACHE PATH "Root of the adhd (CRAS) source tree")

set(ANDROID_T_INC
    "/home/jaewon/workspace/R144/whaleos/chroot/opt/android-t/amd64/usr/include"
    CACHE PATH "Android-T system headers (hardware/, cutils/, …)")

# -----------------------------------------------------------------------
# libcras (static) — same sources/flags as Android.bp
# -----------------------------------------------------------------------
add_library(cras STATIC
    ${ADHD_ROOT}/cras/common/check.c
    ${ADHD_ROOT}/cras/src/common/cras_audio_format.c
    ${ADHD_ROOT}/cras/src/common/cras_config.c
    ${ADHD_ROOT}/cras/src/common/cras_file_wait.c
    ${ADHD_ROOT}/cras/src/common/cras_shm.c
    ${ADHD_ROOT}/cras/src/common/cras_string.c
    ${ADHD_ROOT}/cras/src/common/cras_util.c
    ${ADHD_ROOT}/cras/src/common/edid_utils.c
    ${ADHD_ROOT}/cras/src/libcras/cras_client.c
    ${ADHD_ROOT}/cras/src/libcras/cras_helpers.c
)

target_include_directories(cras PUBLIC
    ${ADHD_ROOT}/cras/include
    ${ADHD_ROOT}/cras/src/common
)

target_include_directories(cras PRIVATE
    ${ADHD_ROOT}/cras/common
    ${ADHD_ROOT}
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor
    ${ANDROID_T_INC}
)

target_compile_definitions(cras PRIVATE
    CRAS_SOCKET_FILE_DIR="/var/run/cras"
    __ANDROID__
)

target_compile_options(cras PRIVATE
    -fPIC
    -std=gnu11
    -Wall
    -Wno-sign-compare
    -Wno-unused-function
    -Wno-unused-parameter
    -Wno-missing-field-initializers
)

# -----------------------------------------------------------------------
# audio.primary.cras.so — the Android HAL
# -----------------------------------------------------------------------
add_library(audio.primary.cras SHARED
    audio_cras_hal.c
    compat.c
)

set_target_properties(audio.primary.cras PROPERTIES PREFIX "")

target_include_directories(audio.primary.cras PRIVATE
    ${ADHD_ROOT}/cras/include
    ${ADHD_ROOT}/cras/src/common
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor
    ${ANDROID_T_INC}
)

target_compile_definitions(audio.primary.cras PRIVATE
    CRAS_SOCKET_FILE_DIR="/var/run/cras"
    __ANDROID__
)

target_link_libraries(audio.primary.cras PRIVATE
    cras
)
