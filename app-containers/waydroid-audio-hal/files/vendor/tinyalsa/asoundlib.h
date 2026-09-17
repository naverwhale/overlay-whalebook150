/* Copyright 2026 NAVER Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Minimal tinyalsa stub for CRAS HAL compilation.
 * We only need the pcm_format type and pcm_format_to_bits() macro.
 * The actual runtime linking happens against Android's libtinyalsa.so.
 */
#ifndef TINYALSA_ASOUNDLIB_H
#define TINYALSA_ASOUNDLIB_H

enum pcm_format {
    PCM_FORMAT_INVALID = -1,
    PCM_FORMAT_S16_LE = 0,
    PCM_FORMAT_S32_LE,
    PCM_FORMAT_S8,
    PCM_FORMAT_S24_LE,
    PCM_FORMAT_S24_3LE,
    PCM_FORMAT_MAX,
};

static inline int pcm_format_to_bits(enum pcm_format format) {
    switch (format) {
        case PCM_FORMAT_S8: return 8;
        case PCM_FORMAT_S24_3LE: return 24;
        case PCM_FORMAT_S16_LE: return 16;
        case PCM_FORMAT_S24_LE:
        case PCM_FORMAT_S32_LE: return 32;
        default: return -1;
    }
}

#endif /* TINYALSA_ASOUNDLIB_H */
