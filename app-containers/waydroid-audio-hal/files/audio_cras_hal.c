/* Copyright 2026 NAVER Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/*
 * Android Legacy Audio HAL — ChromeOS CRAS backend
 *
 * Delivers Android audio to the ChromeOS CRAS audio server
 * via the Unix socket bind-mounted at /var/run/cras inside the container.
 *
 * Output: ring-buffer between out_write() and the CRAS playback callback.
 * Input:  ring-buffer between the CRAS capture callback and in_read().
 */

#define LOG_TAG "audio_hw_cras"

#include <hardware/audio.h>
#include <hardware/hardware.h>
#include <cutils/log.h>

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cras_client.h"
#include "cras_helpers.h"
#include "cras_audio_format.h"

/* ------------------------------------------------------------------ */
/* Ring buffer — caller holds lock                                      */
/* ------------------------------------------------------------------ */

struct rb {
    uint8_t *buf;
    size_t   size;   /* allocated bytes; capacity = size - 1 */
    size_t   rp;     /* read pointer  */
    size_t   wp;     /* write pointer */
};

static int rb_init(struct rb *r, size_t size) {
    r->buf = malloc(size);
    if (!r->buf) return -ENOMEM;
    r->size = size;
    r->rp = r->wp = 0;
    return 0;
}

static void rb_free(struct rb *r) { free(r->buf); r->buf = NULL; }

static size_t rb_avail(const struct rb *r) {
    if (r->wp >= r->rp) return r->wp - r->rp;
    return r->size - r->rp + r->wp;
}

static size_t rb_free_space(const struct rb *r) {
    return r->size - 1 - rb_avail(r);
}

static void rb_write(struct rb *r, const uint8_t *src, size_t n) {
    size_t tail = r->size - r->wp;
    if (n <= tail) {
        memcpy(r->buf + r->wp, src, n);
        r->wp = (r->wp + n) % r->size;
    } else {
        memcpy(r->buf + r->wp, src, tail);
        memcpy(r->buf, src + tail, n - tail);
        r->wp = n - tail;
    }
}

static void rb_read(struct rb *r, uint8_t *dst, size_t n) {
    size_t tail = r->size - r->rp;
    if (n <= tail) {
        memcpy(dst, r->buf + r->rp, n);
        r->rp = (r->rp + n) % r->size;
    } else {
        memcpy(dst, r->buf + r->rp, tail);
        memcpy(dst + tail, r->buf, n - tail);
        r->rp = n - tail;
    }
}

/* ------------------------------------------------------------------ */
/* Shared constants                                                     */
/* ------------------------------------------------------------------ */

#define DEFAULT_SAMPLE_RATE   48000
#define RING_BUF_MS           400   /* ring buffer duration in ms */

/* Absolute timeout helper */
static void deadline_ms(struct timespec *ts, int ms) {
    clock_gettime(CLOCK_REALTIME, ts);
    ts->tv_sec  += ms / 1000;
    ts->tv_nsec += (ms % 1000) * 1000000L;
    if (ts->tv_nsec >= 1000000000L) {
        ts->tv_sec++;
        ts->tv_nsec -= 1000000000L;
    }
}

/* ------------------------------------------------------------------ */
/* Output stream                                                        */
/* ------------------------------------------------------------------ */

struct cras_out {
    struct audio_stream_out  stream;

    struct cras_client      *cras;
    cras_stream_id_t         stream_id;

    struct rb                rb;
    pthread_mutex_t          lock;
    pthread_cond_t           cond;

    uint32_t  sample_rate;
    uint32_t  channels;
    audio_channel_mask_t channel_mask;
    int       standby;
};

static int out_playback_cb(struct cras_client *client,
                           cras_stream_id_t id,
                           uint8_t *cap, uint8_t *pb,
                           unsigned int frames,
                           const struct timespec *cap_ts,
                           const struct timespec *pb_ts,
                           void *arg)
{
    struct cras_out *out = arg;
    size_t bytes = (size_t)frames * out->channels * 2; /* S16_LE */

    pthread_mutex_lock(&out->lock);
    size_t avail = rb_avail(&out->rb);
    if (avail >= bytes) {
        rb_read(&out->rb, pb, bytes);
    } else {
        if (avail > 0) rb_read(&out->rb, pb, avail);
        memset(pb + avail, 0, bytes - avail);
    }
    pthread_cond_broadcast(&out->cond);
    pthread_mutex_unlock(&out->lock);
    return (int)frames;
}

static int out_error_cb(struct cras_client *c, cras_stream_id_t id,
                        int err, void *arg)
{
    ALOGE("CRAS output stream error %d", err);
    return 0;
}

static int start_cras_out(struct cras_out *out) {
    /* Ensure CRAS is connected before adding stream. Uses the background
     * thread path (thread already running) so the wait happens on server_event_fd
     * instead of spinning with ppoll in the calling thread. */
    int rc = cras_client_connect_timeout(out->cras, 3000);
    if (rc) {
        ALOGE("cras_client_connect_timeout(OUT) = %d", rc);
        return rc;
    }
    rc = cras_helper_add_stream_simple(
             out->cras,
             CRAS_STREAM_OUTPUT,
             out,
             out_playback_cb,
             out_error_cb,
             SND_PCM_FORMAT_S16_LE,
             out->sample_rate,
             out->channels,
             -1,
             &out->stream_id);
    if (rc) ALOGE("cras_helper_add_stream_simple(OUT) = %d", rc);
    return rc;
}

/* audio_stream_out vtable */
static uint32_t out_get_sample_rate(const struct audio_stream *s)
    { return ((struct cras_out *)s)->sample_rate; }
static int out_set_sample_rate(struct audio_stream *s, uint32_t r)
    { return 0; }
static audio_format_t out_get_format(const struct audio_stream *s)
    { return AUDIO_FORMAT_PCM_16_BIT; }
static int out_set_format(struct audio_stream *s, audio_format_t f)
    { return -ENOSYS; }
static audio_channel_mask_t out_get_channels(const struct audio_stream *s)
    { return ((struct cras_out *)s)->channel_mask; }
static size_t out_get_buffer_size(const struct audio_stream *s) {
    struct cras_out *out = (struct cras_out *)s;
    /* 20 ms worth of frames, in bytes */
    return (out->sample_rate / 50) * out->channels * 2;
}
static int out_dump(const struct audio_stream *s, int fd) { return 0; }
static int out_set_params(struct audio_stream *s, const char *kv) { return 0; }
static char *out_get_params(const struct audio_stream *s, const char *k)
    { return strdup(""); }
static int out_add_effect(const struct audio_stream *s, effect_handle_t e) { return 0; }
static int out_rm_effect(const struct audio_stream *s, effect_handle_t e) { return 0; }
static int out_standby(struct audio_stream *s) {
    struct cras_out *out = (struct cras_out *)s;
    pthread_mutex_lock(&out->lock);
    out->standby = 1;
    pthread_mutex_unlock(&out->lock);
    return 0;
}
static uint32_t out_get_latency(const struct audio_stream_out *s)
    { return 20; /* ms */ }
static int out_set_volume(struct audio_stream_out *s, float l, float r)
    { return 0; }
static int out_get_render_pos(const struct audio_stream_out *s, uint32_t *f)
    { *f = 0; return -EINVAL; }
static int out_get_next_write_ts(const struct audio_stream_out *s, int64_t *ts)
    { return -EINVAL; }
static int out_get_pres_pos(const struct audio_stream_out *s,
                             uint64_t *f, struct timespec *ts)
    { return -EINVAL; }

static ssize_t out_write(struct audio_stream_out *stream,
                          const void *buffer, size_t bytes)
{
    struct cras_out *out = (struct cras_out *)stream;
    const uint8_t *src = buffer;
    size_t written = 0;

    pthread_mutex_lock(&out->lock);

    if (out->standby) {
        out->standby = 0;
        if (!out->stream_id) {
            int rc = start_cras_out(out);
            if (rc) {
                out->standby = 1;  /* allow retry on next write */
                pthread_mutex_unlock(&out->lock);
                return -EIO;
            }
        }
    }

    while (written < bytes) {
        size_t space = rb_free_space(&out->rb);
        if (space > 0) {
            size_t n = bytes - written;
            if (n > space) n = space;
            rb_write(&out->rb, src + written, n);
            written += n;
        } else {
            struct timespec ts;
            deadline_ms(&ts, 200);
            pthread_cond_timedwait(&out->cond, &out->lock, &ts);
        }
    }

    pthread_mutex_unlock(&out->lock);
    return (ssize_t)written;
}

/* ------------------------------------------------------------------ */
/* Input stream                                                         */
/* ------------------------------------------------------------------ */

struct cras_in {
    struct audio_stream_in  stream;

    struct cras_client     *cras;
    cras_stream_id_t        stream_id;

    struct rb               rb;
    pthread_mutex_t         lock;
    pthread_cond_t          cond;

    uint32_t  sample_rate;
    uint32_t  channels;
    audio_channel_mask_t channel_mask;
};

static int in_capture_cb(struct cras_client *client,
                          cras_stream_id_t id,
                          uint8_t *cap, uint8_t *pb,
                          unsigned int frames,
                          const struct timespec *cap_ts,
                          const struct timespec *pb_ts,
                          void *arg)
{
    struct cras_in *in = arg;
    size_t bytes = (size_t)frames * in->channels * 2;

    pthread_mutex_lock(&in->lock);
    size_t space = rb_free_space(&in->rb);
    size_t n = bytes < space ? bytes : space;
    if (n > 0) rb_write(&in->rb, cap, n);
    pthread_cond_broadcast(&in->cond);
    pthread_mutex_unlock(&in->lock);
    return (int)frames;
}

static int in_error_cb(struct cras_client *c, cras_stream_id_t id,
                       int err, void *arg)
{
    ALOGE("CRAS input stream error %d", err);
    return 0;
}

static uint32_t in_get_sample_rate(const struct audio_stream *s)
    { return ((struct cras_in *)s)->sample_rate; }
static int in_set_sample_rate(struct audio_stream *s, uint32_t r)
    { return 0; }
static audio_format_t in_get_format(const struct audio_stream *s)
    { return AUDIO_FORMAT_PCM_16_BIT; }
static int in_set_format(struct audio_stream *s, audio_format_t f)
    { return -ENOSYS; }
static audio_channel_mask_t in_get_channels(const struct audio_stream *s)
    { return ((struct cras_in *)s)->channel_mask; }
static size_t in_get_buffer_size(const struct audio_stream *s) {
    struct cras_in *in = (struct cras_in *)s;
    return (in->sample_rate / 50) * in->channels * 2;
}
static int in_dump(const struct audio_stream *s, int fd) { return 0; }
static int in_set_params(struct audio_stream *s, const char *kv) { return 0; }
static char *in_get_params(const struct audio_stream *s, const char *k)
    { return strdup(""); }
static int in_add_effect(const struct audio_stream *s, effect_handle_t e) { return 0; }
static int in_rm_effect(const struct audio_stream *s, effect_handle_t e) { return 0; }
static int in_standby(struct audio_stream *s) { return 0; }
static uint32_t in_frames_lost(struct audio_stream_in *s) { return 0; }

static ssize_t in_read(struct audio_stream_in *stream,
                        void *buffer, size_t bytes)
{
    struct cras_in *in = (struct cras_in *)stream;
    uint8_t *dst = buffer;
    size_t done = 0;

    pthread_mutex_lock(&in->lock);
    while (done < bytes) {
        size_t avail = rb_avail(&in->rb);
        if (avail > 0) {
            size_t n = bytes - done;
            if (n > avail) n = avail;
            rb_read(&in->rb, dst + done, n);
            done += n;
        } else {
            struct timespec ts;
            deadline_ms(&ts, 500);
            int rc = pthread_cond_timedwait(&in->cond, &in->lock, &ts);
            if (rc == ETIMEDOUT) {
                memset(dst + done, 0, bytes - done);
                done = bytes;
            }
        }
    }
    pthread_mutex_unlock(&in->lock);
    return (ssize_t)done;
}

/* ------------------------------------------------------------------ */
/* Device                                                               */
/* ------------------------------------------------------------------ */

struct cras_adev {
    struct audio_hw_device hw;
    pthread_mutex_t lock;
    float master_vol;
    struct cras_client *cras;
};

static int adev_open_output_stream(struct audio_hw_device *dev,
                                    audio_io_handle_t handle,
                                    audio_devices_t devices,
                                    audio_output_flags_t flags,
                                    struct audio_config *config,
                                    struct audio_stream_out **stream_out,
                                    const char *address)
{
    struct cras_adev *adev = (struct cras_adev *)dev;
    struct cras_out *out = calloc(1, sizeof(*out));
    if (!out) return -ENOMEM;

    out->sample_rate  = config->sample_rate ? config->sample_rate : DEFAULT_SAMPLE_RATE;
    out->channel_mask = config->channel_mask ? config->channel_mask
                                              : AUDIO_CHANNEL_OUT_STEREO;
    out->channels     = audio_channel_count_from_out_mask(out->channel_mask);
    if (!out->channels) out->channels = 2;
    out->standby = 1;

    config->format       = AUDIO_FORMAT_PCM_16_BIT;
    config->channel_mask = out->channel_mask;
    config->sample_rate  = out->sample_rate;

    out->cras = adev->cras;

    size_t ring_bytes = (size_t)(out->sample_rate * RING_BUF_MS / 1000)
                        * out->channels * 2 + 1;
    if (rb_init(&out->rb, ring_bytes)) {
        free(out);
        return -ENOMEM;
    }

    pthread_mutex_init(&out->lock, NULL);
    pthread_cond_init(&out->cond, NULL);

    out->stream.common.get_sample_rate    = out_get_sample_rate;
    out->stream.common.set_sample_rate    = out_set_sample_rate;
    out->stream.common.get_buffer_size    = out_get_buffer_size;
    out->stream.common.get_channels       = out_get_channels;
    out->stream.common.get_format         = out_get_format;
    out->stream.common.set_format         = out_set_format;
    out->stream.common.standby            = out_standby;
    out->stream.common.dump               = out_dump;
    out->stream.common.set_parameters     = out_set_params;
    out->stream.common.get_parameters     = out_get_params;
    out->stream.common.add_audio_effect   = out_add_effect;
    out->stream.common.remove_audio_effect= out_rm_effect;
    out->stream.get_latency               = out_get_latency;
    out->stream.set_volume                = out_set_volume;
    out->stream.write                     = out_write;
    out->stream.get_render_position       = out_get_render_pos;
    out->stream.get_next_write_timestamp  = out_get_next_write_ts;
    out->stream.get_presentation_position = out_get_pres_pos;

    *stream_out = &out->stream;
    ALOGI("opened output: %u Hz %u ch", out->sample_rate, out->channels);
    return 0;
}

static void adev_close_output_stream(struct audio_hw_device *dev,
                                      struct audio_stream_out *stream)
{
    struct cras_out *out = (struct cras_out *)stream;
    if (out->stream_id)
        cras_client_rm_stream(out->cras, out->stream_id);
    rb_free(&out->rb);
    pthread_mutex_destroy(&out->lock);
    pthread_cond_destroy(&out->cond);
    free(out);
}

static int adev_open_input_stream(struct audio_hw_device *dev,
                                   audio_io_handle_t handle,
                                   audio_devices_t devices,
                                   struct audio_config *config,
                                   struct audio_stream_in **stream_in,
                                   audio_input_flags_t flags,
                                   const char *address,
                                   audio_source_t source)
{
    struct cras_adev *adev = (struct cras_adev *)dev;
    struct cras_in *in = calloc(1, sizeof(*in));
    if (!in) return -ENOMEM;

    in->sample_rate  = config->sample_rate ? config->sample_rate : DEFAULT_SAMPLE_RATE;
    in->channel_mask = config->channel_mask ? config->channel_mask
                                            : AUDIO_CHANNEL_IN_STEREO;
    in->channels     = audio_channel_count_from_in_mask(in->channel_mask);
    if (!in->channels) in->channels = 2;

    config->format       = AUDIO_FORMAT_PCM_16_BIT;
    config->channel_mask = in->channel_mask;
    config->sample_rate  = in->sample_rate;

    in->cras = adev->cras;

    size_t ring_bytes = (size_t)(in->sample_rate * RING_BUF_MS / 1000)
                        * in->channels * 2 + 1;
    if (rb_init(&in->rb, ring_bytes)) {
        free(in);
        return -ENOMEM;
    }

    pthread_mutex_init(&in->lock, NULL);
    pthread_cond_init(&in->cond, NULL);

    int rc = cras_client_connect_timeout(in->cras, 3000);
    if (rc) {
        ALOGE("cras_client_connect_timeout(IN) = %d", rc);
        rb_free(&in->rb);
        free(in);
        return -EIO;
    }
    rc = cras_helper_add_stream_simple(
             in->cras,
             CRAS_STREAM_INPUT,
             in,
             in_capture_cb,
             in_error_cb,
             SND_PCM_FORMAT_S16_LE,
             in->sample_rate,
             in->channels,
             -1,
             &in->stream_id);
    if (rc) {
        ALOGE("cras_helper_add_stream_simple(IN) = %d", rc);
        rb_free(&in->rb);
        free(in);
        return -EIO;
    }

    in->stream.common.get_sample_rate    = in_get_sample_rate;
    in->stream.common.set_sample_rate    = in_set_sample_rate;
    in->stream.common.get_buffer_size    = in_get_buffer_size;
    in->stream.common.get_channels       = in_get_channels;
    in->stream.common.get_format         = in_get_format;
    in->stream.common.set_format         = in_set_format;
    in->stream.common.standby            = in_standby;
    in->stream.common.dump               = in_dump;
    in->stream.common.set_parameters     = in_set_params;
    in->stream.common.get_parameters     = in_get_params;
    in->stream.common.add_audio_effect   = in_add_effect;
    in->stream.common.remove_audio_effect= in_rm_effect;
    in->stream.read                      = in_read;
    in->stream.get_input_frames_lost     = in_frames_lost;

    *stream_in = &in->stream;
    ALOGI("opened input: %u Hz %u ch", in->sample_rate, in->channels);
    return 0;
}

static void adev_close_input_stream(struct audio_hw_device *dev,
                                     struct audio_stream_in *stream)
{
    struct cras_in *in = (struct cras_in *)stream;
    if (in->stream_id)
        cras_client_rm_stream(in->cras, in->stream_id);
    rb_free(&in->rb);
    pthread_mutex_destroy(&in->lock);
    pthread_cond_destroy(&in->cond);
    free(in);
}

static int adev_init_check(const struct audio_hw_device *d) { return 0; }
static int adev_set_voice_vol(struct audio_hw_device *d, float v) { return 0; }
static int adev_set_master_vol(struct audio_hw_device *d, float v) {
    ((struct cras_adev *)d)->master_vol = v; return 0;
}
static int adev_get_master_vol(struct audio_hw_device *d, float *v) {
    *v = ((struct cras_adev *)d)->master_vol; return 0;
}
static int adev_set_mode(struct audio_hw_device *d, audio_mode_t m) { return 0; }
static int adev_set_mic_mute(struct audio_hw_device *d, bool s) { return 0; }
static int adev_get_mic_mute(const struct audio_hw_device *d, bool *s)
    { *s = false; return 0; }
static int adev_set_params(struct audio_hw_device *d, const char *kv) { return 0; }
static char *adev_get_params(const struct audio_hw_device *d, const char *k)
    { return strdup(""); }
static size_t adev_get_input_buf_size(const struct audio_hw_device *d,
                                       const struct audio_config *c)
    { return 4096; }
static int adev_dump(const struct audio_hw_device *d, int fd) { return 0; }
static int adev_set_master_mute(struct audio_hw_device *d, bool m) { return 0; }
static int adev_get_master_mute(struct audio_hw_device *d, bool *m)
    { *m = false; return 0; }

static int adev_close(hw_device_t *dev) {
    struct cras_adev *adev = (struct cras_adev *)dev;
    if (adev->cras) {
        cras_client_stop(adev->cras);
        cras_client_destroy(adev->cras);
    }
    pthread_mutex_destroy(&adev->lock);
    free(adev);
    return 0;
}

static int adev_open(const hw_module_t *module, const char *name,
                      hw_device_t **device)
{
    if (strcmp(name, AUDIO_HARDWARE_INTERFACE) != 0) return -EINVAL;

    struct cras_adev *adev = calloc(1, sizeof(*adev));
    if (!adev) return -ENOMEM;

    adev->master_vol = 1.0f;
    pthread_mutex_init(&adev->lock, NULL);

    /* Create CRAS client and start the background thread now; the actual
     * socket connection is deferred to when the first stream is opened.
     * Starting the thread early lets the background thread handle inotify
     * and EINTR internally, avoiding a blocking call in AudioFlinger's
     * constructor path which has a strict 2-second TimeCheck timer. */
    int rc = cras_client_create(&adev->cras);
    if (rc) {
        ALOGE("cras_client_create = %d", rc);
        pthread_mutex_destroy(&adev->lock);
        free(adev);
        return -EIO;
    }
    rc = cras_client_run_thread(adev->cras);
    if (rc) {
        ALOGE("cras_client_run_thread = %d", rc);
        cras_client_destroy(adev->cras);
        pthread_mutex_destroy(&adev->lock);
        free(adev);
        return -EIO;
    }
    /* Kick off async connect; the background thread connects without
     * blocking the caller. Streams will call connect_timeout on first use. */
    cras_client_connect_async(adev->cras);

    adev->hw.common.tag     = HARDWARE_DEVICE_TAG;
    adev->hw.common.version = AUDIO_DEVICE_API_VERSION_2_0;
    adev->hw.common.module  = (hw_module_t *)module;
    adev->hw.common.close   = adev_close;

    adev->hw.init_check            = adev_init_check;
    adev->hw.set_voice_volume      = adev_set_voice_vol;
    adev->hw.set_master_volume     = adev_set_master_vol;
    adev->hw.get_master_volume     = adev_get_master_vol;
    adev->hw.set_mode              = adev_set_mode;
    adev->hw.set_mic_mute          = adev_set_mic_mute;
    adev->hw.get_mic_mute          = adev_get_mic_mute;
    adev->hw.set_parameters        = adev_set_params;
    adev->hw.get_parameters        = adev_get_params;
    adev->hw.get_input_buffer_size = adev_get_input_buf_size;
    adev->hw.open_output_stream    = adev_open_output_stream;
    adev->hw.close_output_stream   = adev_close_output_stream;
    adev->hw.open_input_stream     = adev_open_input_stream;
    adev->hw.close_input_stream    = adev_close_input_stream;
    adev->hw.dump                  = adev_dump;
    adev->hw.set_master_mute       = adev_set_master_mute;
    adev->hw.get_master_mute       = adev_get_master_mute;

    *device = &adev->hw.common;
    ALOGI("CRAS audio HAL opened (socket: /var/run/cras/.cras_socket)");
    return 0;
}

static struct hw_module_methods_t hal_module_methods = {
    .open = adev_open,
};

struct audio_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag                = HARDWARE_MODULE_TAG,
        .module_api_version = AUDIO_MODULE_API_VERSION_0_1,
        .hal_api_version    = HARDWARE_HAL_API_VERSION,
        .id                 = AUDIO_HARDWARE_MODULE_ID,
        .name               = "CRAS audio HAL",
        .author             = "WhaleOS",
        .methods            = &hal_module_methods,
    },
};
