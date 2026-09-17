/* Copyright 2026 NAVER Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Android compatibility stubs for CRAS HAL.
 *
 * liblog.so and libcutils.so symbols are not reachable from the sphal linker
 * namespace when the HAL has no NEEDED entries for those libraries.  Providing
 * them here avoids "cannot locate symbol" dlopen failures without adding
 * NEEDED entries that would fail ChromeOS dep_check.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

int __android_log_print(int prio, const char* tag, const char* fmt, ...) {
    va_list ap;
    (void)prio;
    va_start(ap, fmt);
    fprintf(stderr, "[%s] ", tag ? tag : "CRAS");
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    return 0;
}

int ashmem_create_region(const char* name, size_t size) {
    int fd = memfd_create(name ? name : "ashmem", MFD_CLOEXEC);
    if (fd < 0)
        return -errno;
    if (ftruncate(fd, (off_t)size) < 0) {
        int e = errno;
        close(fd);
        return -e;
    }
    return fd;
}

int ashmem_set_prot_region(int fd, int prot) {
    (void)fd;
    (void)prot;
    return 0;
}
