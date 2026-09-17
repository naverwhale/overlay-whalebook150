#!/usr/bin/env python3
# Copyright 2026 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Fix the missing PendingIntent.FLAG_IMMUTABLE in WayDroidService.removeApp.

The Waydroid LineageOS 20 image ships /system/framework/org.lineageos.
platform.jar whose WayDroidService$4.removeApp() builds a broadcast
PendingIntent with FLAG_UPDATE_CURRENT (0x08000000) only.  Android 12+
enforces PENDING_INTENT_EXPLICIT_MUTABILITY_REQUIRED for callers with
targetSdk>=31, and system_server (where the service runs) meets that
threshold.  PendingIntent.checkFlags() then throws IllegalArgument-
Exception, which the AIDL layer maps to EX_ILLEGAL_ARGUMENT (-3) in the
binder reply.  Client-side Python (waydroid/tools/interfaces/IPlatform.py)
logs it as "Failed with code: -3" and every `waydroid app remove` fails.

installApp() in the same file already uses FLAG_UPDATE_CURRENT|
FLAG_IMMUTABLE (0x0C000000), so the fix is a single-nibble edit:
change removeApp's `const/high16 v4, 0x0800` to `const/high16 v4, 0x0C00`.

This tool locates the exact 4-byte instruction inside classes.dex
(`15 04 00 08` = const/high16 v4, high16=0x0800), replaces the last
byte with 0x0C, recomputes the dex header's Adler32 checksum and SHA-1
signature, and repackages the jar.  It refuses to run if the byte
pattern is found more than once inside removeApp -- ambiguous patches
would silently corrupt unrelated code.

Usage:
    patch_platform_jar.py <input.jar> <output.jar>

Exit code 0 means the jar was patched, exit code 1 means the jar was
already patched (idempotent no-op), exit code >1 means a real error.
"""

from __future__ import annotations

import hashlib
import struct
import sys
import zipfile
import zlib


DEX_NAME = "classes.dex"

# `const/high16 v4, 0x0800` -- FLAG_UPDATE_CURRENT alone.
BUGGY_PATTERN = bytes([0x15, 0x04, 0x00, 0x08])
# `const/high16 v4, 0x0C00` -- FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE.
FIXED_PATTERN = bytes([0x15, 0x04, 0x00, 0x0C])


def _find_code_item_of_remove_app(dex: bytes) -> tuple[int, int]:
    """Return (insns_off, insns_size_bytes) for WayDroidService$*.removeApp."""
    # Parse just enough of the dex header + tables to walk methods.  This
    # avoids a hard dependency on androguard/dexlib during the ebuild.
    if dex[:4] != b"dex\n":
        raise SystemExit(f"Not a dex file (magic={dex[:8]!r})")

    (string_ids_size, string_ids_off,
     type_ids_size, type_ids_off,
     proto_ids_size, proto_ids_off,
     _field_ids_size, _field_ids_off,
     method_ids_size, method_ids_off,
     class_defs_size, class_defs_off) = struct.unpack_from(
        "<IIIIIIIIIIII", dex, 56)

    def read_uleb128(off: int) -> tuple[int, int]:
        result = 0
        shift = 0
        while True:
            b = dex[off]
            off += 1
            result |= (b & 0x7F) << shift
            if not (b & 0x80):
                return result, off
            shift += 7

    def string_at(idx: int) -> str:
        data_off = struct.unpack_from("<I", dex, string_ids_off + idx * 4)[0]
        _len, off = read_uleb128(data_off)
        end = dex.index(b"\x00", off)
        return dex[off:end].decode("utf-8", errors="replace")

    def type_name(idx: int) -> str:
        return string_at(
            struct.unpack_from("<I", dex, type_ids_off + idx * 4)[0])

    # method_id_item: class_idx u2, proto_idx u2, name_idx u4
    def method_class_and_name(method_idx: int) -> tuple[str, str]:
        class_idx, _proto_idx, name_idx = struct.unpack_from(
            "<HHI", dex, method_ids_off + method_idx * 8)
        return type_name(class_idx), string_at(name_idx)

    # For each class_def, walk its class_data_item -> direct_methods to
    # find code_off of removeApp inside a WayDroidService inner class.
    candidates: list[tuple[int, int]] = []
    for cdef in range(class_defs_size):
        base = class_defs_off + cdef * 32
        class_idx = struct.unpack_from("<I", dex, base)[0]
        class_data_off = struct.unpack_from("<I", dex, base + 24)[0]
        if class_data_off == 0:
            continue
        cname = type_name(class_idx)
        if "WayDroidService" not in cname:
            continue

        # class_data_item: uleb128 counts (static, instance, direct, virtual)
        off = class_data_off
        static_size, off = read_uleb128(off)
        instance_size, off = read_uleb128(off)
        direct_size, off = read_uleb128(off)
        virtual_size, off = read_uleb128(off)
        # Skip static/instance field entries.
        for _ in range(static_size + instance_size):
            _idx_diff, off = read_uleb128(off)
            _access, off = read_uleb128(off)

        method_idx = 0
        for kind_count in (direct_size, virtual_size):
            method_idx_running = 0
            for _ in range(kind_count):
                idx_diff, off = read_uleb128(off)
                method_idx_running += idx_diff
                _access, off = read_uleb128(off)
                code_off, off = read_uleb128(off)
                if code_off == 0:
                    continue
                _cls, name = method_class_and_name(method_idx_running)
                if name != "removeApp":
                    continue
                # code_item: registers u2, ins u2, outs u2, tries u2,
                #            debug_info_off u4, insns_size u4, insns u2[]
                insns_size_words = struct.unpack_from(
                    "<I", dex, code_off + 12)[0]
                candidates.append((code_off + 16, insns_size_words * 2))

    if not candidates:
        raise SystemExit("removeApp not found in any WayDroidService class")
    return candidates[0]  # first match; there is only one


def _patch_dex(dex_in: bytes) -> tuple[bytes, bool]:
    """Return (patched dex, changed) -- changed=False if already patched."""
    insns_off, insns_len = _find_code_item_of_remove_app(dex_in)

    body = dex_in[insns_off:insns_off + insns_len]
    if FIXED_PATTERN in body and BUGGY_PATTERN not in body:
        return dex_in, False  # already patched, nothing to do
    matches = [i for i in range(len(body) - 3)
               if body[i:i + 4] == BUGGY_PATTERN]
    if len(matches) != 1:
        raise SystemExit(
            f"Expected exactly one `const/high16 v4, 0x0800` inside "
            f"removeApp; found {len(matches)} -- refusing to patch")

    patch_off = insns_off + matches[0]
    dex = bytearray(dex_in)
    dex[patch_off + 3] = 0x0C

    # dex_header layout: magic[8], checksum u4, signature[20], file_size u4,
    # header_size u4, endian u4, ...
    # The SHA-1 covers everything from offset 32 to EOF; adler32 covers
    # from offset 12 to EOF (i.e. sig + everything after).
    new_sig = hashlib.sha1(bytes(dex[32:])).digest()
    dex[12:32] = new_sig
    new_adler = zlib.adler32(bytes(dex[12:])) & 0xFFFFFFFF
    struct.pack_into("<I", dex, 8, new_adler)
    return bytes(dex), True


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst = argv[1], argv[2]

    with zipfile.ZipFile(src, "r") as z_in:
        if DEX_NAME not in z_in.namelist():
            raise SystemExit(f"{src} has no {DEX_NAME}")
        dex_in = z_in.read(DEX_NAME)
        dex_out, changed = _patch_dex(dex_in)

        with zipfile.ZipFile(dst, "w", zipfile.ZIP_STORED) as z_out:
            for entry in z_in.infolist():
                if entry.filename == DEX_NAME:
                    z_out.writestr(entry, dex_out)
                else:
                    z_out.writestr(entry, z_in.read(entry.filename))

    if not changed:
        print(f"{src} already contains the fixed removeApp; wrote passthrough")
        return 1
    print(f"Patched {src} -> {dst} ({len(dex_out)} bytes classes.dex)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
