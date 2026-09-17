# WhaleOS

WhaleOS is a ChromiumOS-based operating system. This repository contains
the `overlay-whalebook` board overlay that applies WhaleOS-specific
modifications on top of vanilla ChromiumOS.

This revision of the overlay was generated against ChromiumOS
`release-R150-16700.B` (ChromeOS 16700.64.0, Chrome 150.0.7871.254).
Its release ebuilds were also checked against the branch tip at generation
time, `e6eef189dc71` (ChromeOS 16700.64.0): none of the packages this
overlay modifies had been uprevved upstream to or past the overlay's revision.

## Prerequisites

- Linux x86_64 (Ubuntu 22.04+ recommended)
- 100 GB+ free disk space
- 32 GB+ USB flash drive for the test image (about 22 GB: the overlay's `usb`
  disk layout in `scripts/disk_layout.json` reserves a 16 GiB stateful partition)
- [ChromiumOS developer prerequisites](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/developer_guide.md#Prerequisites)

## Build WhaleOS Platform

### 1. Checkout ChromiumOS (R150)

```bash
mkdir chromiumos && cd chromiumos
repo init -u https://chromium.googlesource.com/chromiumos/manifest.git \
     -b release-R150-16700.B
repo sync -j8
```

### 2. Add WhaleOS overlay

```bash
git clone https://github.com/naverwhale/overlay-whalebook150.git \
     src/overlays/overlay-whalebook
```

### 3. Enter the SDK and set up the board

```bash
cros_sdk
setup_board --board=whalebook
```

### 4. Build packages and image

```bash
cros build-packages --board=whalebook
cros build-image --board=whalebook --noenable_rootfs_verification test
```

`chromeos-base/chromeos-chrome` is built from the Chromium source revision
pinned by the overlay (150.0.7871.254); newer upstream uprevs are masked in
`profiles/base/package.mask` so the overlay's ebuild is always selected. The
same file pins the packages WhaleOS keeps at a lower version than upstream.
Ebuilds this overlay derives from upstream release ebuilds carry a revision one
above the upstream one as of the ChromiumOS revision named at the top of this
file, so portage selects them by version rather than by overlay priority and
`equery-whalebook which <category/package>` shows which ebuild is in use. The
release branch keeps moving after that point: if a later `repo sync` brings in
an upstream uprev of one of these packages, portage selects the upstream ebuild
over the overlay's and a newer revision of this overlay is needed.

### 5. Flash to USB

```bash
cros flash usb:// whalebook/latest
```

Boot from USB and follow the on-screen installer to install WhaleOS.

The image boots into the Chromium OOBE. Google account sign-in is not
available in this build because it carries no Google API keys (Chromium builds
need their own keys and an allow-listed test account to sign in); use
**Browse as Guest** to check the image, or continue with the Whale browser
below, which signs in with a whalespace account.

## Run Whale Browser

After booting WhaleOS, replace the default Chromium with Whale:

```bash
# SSH into the device
ssh -i chromite/ssh_keys/testing_rsa \
    root@<DEVICE_IP>

# Remount root filesystem as read-write
mount -o rw,remount /

# Remove default browser
rm -rf /opt/google/chrome

# Download and install Whale
wget https://github.com/naverwhale/overlay-whalebook150/releases/download/r150/chrome.tar.gz
tar xzf chrome.tar.gz -C /opt/google/

# Reboot
reboot
```

## Acknowledgements

This repository includes code derived from the following third-party open source software.

### [Chromium OS](https://chromium.googlesource.com/chromiumos/manifest.git/+/refs/heads/release-R150-16700.B)
The patches and overlays in this repository are designed to apply on top of
ChromiumOS and follow the license terms of the
[ChromiumOS source repository](https://chromium.googlesource.com/chromiumos/).

### Third-party files included in this repository
These files are part of the repository itself (not fetched at build time) and
keep their original licenses; each entry says where its notice text lives.
- [intel/FSP - KabylakeFspBinPkg](https://github.com/intel/FSP/tree/master/KabylakeFspBinPkg) (BSD-3-Clause, per-file headers) - the headers under `sys-boot/coreboot/files/3rdparty/fsp/KabylakeFspBinPkg/Include/`, inherited from upstream chromiumos-overlay; the notice text is in `licenses/Intel-FSP-headers`. No FSP binary is included.
- [minigbm (Waydroid fork)](https://github.com/WayDroid/android_external_minigbm) (BSD-3-Clause; Apache-2.0 and MIT parts per its `Android.bp`) - source snapshot `app-containers/waydroid-gralloc-fix/files/waydroid-minigbm-*.tar.gz`, built with the WhaleOS patches next to it; the upstream `LICENSE` is inside the tarball, the pinned commit is in the ebuild and the notice text is in `licenses/WayDroid-minigbm`.
- [libdrm (Waydroid fork)](https://github.com/WayDroid/android_external_libdrm) (MIT, per-file headers) - source snapshot `app-containers/waydroid-gralloc-fix/files/waydroid-libdrm-*.tar.gz`, used only for its headers at build time; no code from it ends up in the built library; the notice text is in `licenses/WayDroid-libdrm`.
- Android Open Source Project audio HAL headers (Apache-2.0) - `app-containers/waydroid-audio-hal/files/vendor/system/`; attribution in `files/vendor/NOTICE` and `licenses/AOSP-audio-headers`.
- [LineageOS](https://lineageos.org) 20 / AOSP external camera HAL `camera.device@3.4-external-impl.so` (Apache-2.0) - prebuilt binary with a 6-byte WhaleOS modification, `app-containers/waydroid-camera-hal-fix/files/`; the change and the attribution are described in the ebuild and in `licenses/AOSP-camera-hal`.
- Android Open Source Project init and VINTF files (Apache-2.0) - `app-containers/waydroid/files/android-overlay/`, modified for the Waydroid container; attribution and the statement of changes in `licenses/AOSP-waydroid-overlay`.
- ChromiumOS Korean handwriting language pack ([chromeos-languagepacks/handwriting-ko](https://chromium.googlesource.com/chromiumos/overlays/chromiumos-overlay/+/refs/heads/main/chromeos-languagepacks/handwriting-ko/), BSD-Google) - model files under `chromeos-base/ml/files/ko/`, installed into the root filesystem instead of the downloadable DLC.
- [linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git) Realtek `rtw88/rtw8821c_fw.bin` (Realtek firmware licence, `LICENCE.rtlwifi_firmware`) - `sys-kernel/linux-firmware/files/`; not part of the ChromiumOS linux-firmware checkout. It is the upstream binary unchanged (md5 `2638a40042a27e98df2f7929c8eee760`) and the licence text is copied next to it in `licenses/LICENCE.rtlwifi_firmware`.

### Third-party projects patched or fetched at build time
The overlay carries ebuilds and patches for these projects; their sources are
downloaded at build time and keep their original licenses.
- [Waydroid](https://github.com/waydroid/waydroid) (GPL-3.0-or-later) - patches under `app-containers/waydroid/files/`.
- [LXC](https://github.com/lxc/lxc) (LGPL-2.1) - patch under `app-containers/lxc/files/`.
- [ChromiumOS adhd / CRAS](https://chromium.googlesource.com/chromiumos/third_party/adhd/) (BSD-Google) - patch under `app-containers/waydroid-audio-hal/files/`; the CRAS client sources are compiled into the Waydroid audio HAL.
- [libgbinder](https://github.com/mer-hybris/libgbinder) and [libglibutil](https://github.com/sailfishos/libglibutil) (BSD) - ebuilds only.
- [gbinder-python](https://github.com/waydroid/gbinder-python) (GPL-3.0) - ebuild only.
- [LineageOS](https://lineageos.org) / Android (AOSP) system and vendor images (Apache-2.0 and others) - downloaded at build time by `app-containers/waydroid-images`; notices are in `licenses/`.

## License

Unless stated otherwise in a file header, the WhaleOS-authored files in this
repository (ebuilds, patches, scripts and configuration) are licensed under
the BSD-style license in [`LICENSE`](./LICENSE). Patches carry the license of
the project they modify.
