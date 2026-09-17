# Copyright 2024 NAVER Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2
# Based on https://data.gpo.zugaina.org/guru/app-containers/waydroid/waydroid-1.6.2.ebuild

EAPI=7

PYTHON_COMPAT=( python3_11 )

inherit python-r1 linux-info

PATCHES=(
	"${FILESDIR}/0001-config-base-chromeos-fixes.patch"
	"${FILESDIR}/0002-lxc-pulse-socket-optional.patch"
	"${FILESDIR}/0003-waydroid-net-checksum-optional.patch"
	"${FILESDIR}/0004-lxc-adb-insecure-debuggable.patch"
	"${FILESDIR}/0005-chromeos-session-fixes.patch"
	# 0006 requires the whaleos_waydroid SELinux domain (see
	# platform2/sepolicy/policy/chromeos/whaleos_waydroid.te) to
	# grant cros_cras_client() to the container audioserver.  That
	# domain ships in chromeos-base/selinux-policy; the dep is
	# implicit because selinux-policy is part of every WhaleOS image.
	"${FILESDIR}/0006-cras-audio-support.patch"
	"${FILESDIR}/0007-chromeos-stateful-preinstalled-images-path.patch"
	"${FILESDIR}/0008-use-usr-local-work-path.patch"
	"${FILESDIR}/0009-data-exec-initrc-inject.patch"
	"${FILESDIR}/0011-camera-and-gralloc-overlay.patch"
	"${FILESDIR}/0012-lxc-proc-sys-kernel-ro.patch"
	"${FILESDIR}/0013-lxc-proc-sys-vm-abi-ro.patch"
	"${FILESDIR}/0014-config-base-drop-wake-alarm-cap.patch"
	"${FILESDIR}/0015-hardware-manager-suspend-noop.patch"
)

DESCRIPTION="Container-based Android compatibility layer for Linux"
HOMEPAGE="https://waydroid.org https://github.com/waydroid/waydroid"
SRC_URI="https://github.com/waydroid/waydroid/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

# GPL-3+ GPL-3    - upstream waydroid (github.com/waydroid/waydroid), which
#                   says GPL-3.0-or-later in every source header, plus our
#                   patches in ${FILESDIR}.  Both names are needed: the
#                   GPL-3+ license file is a two-line pointer ("see GPL-3
#                   for the full text") and licenses_lib.py only expands
#                   GPL-2+ and LGPL-2+ to their base license, not GPL-3+,
#                   so listing GPL-3+ alone drops the license text from
#                   the credits page.
# AOSP-waydroid-overlay / Apache-2.0
#                 - files/android-overlay/ ships three Android init and VINTF
#                   files derived from AOSP that override the container
#                   image's own: audioserver.rc,
#                   android.hardware.audio.service.rc and the vendor VINTF
#                   manifest.xml.  Stock Apache-2.0 has no copyright notice
#                   and chromite/licensing does not scan sources for
#                   Apache-2.0, so the attribution and the section 4 b
#                   notice of our changes live in the custom license.
# BSD             - files/android-overlay/system/etc/init/init.cras-audio.rc,
#                   written at NAVER.  The attribution text ships as
#                   files/LICENSE.whaleos (not files/LICENSE: waydroid itself
#                   is GPL-3, so a bare LICENSE next to the ebuild would read
#                   as the package licence) and src_unpack copies it to
#                   ${WORKDIR}/LICENSE.whaleos so that chromite's license
#                   scan finds it in any tree, including the public board
#                   overlay built against vanilla ChromiumOS.  It has to be
#                   src_unpack, not src_prepare: when license.json is missing
#                   from the vdb, `licenses --generate-licenses` (run by
#                   build_image) only runs `ebuild ... unpack` before scanning
#                   the work dir.  This overlay also carries the same text as
#                   licenses/copyright-attribution/app-containers/waydroid,
#                   which chromite prefers when present; keep the two files
#                   identical.  Without either the scan would credit the
#                   upstream waydroid LICENSE file (GPL-3 text) instead.
LICENSE="AOSP-waydroid-overlay Apache-2.0 BSD GPL-3 GPL-3+"
SLOT="0"
KEYWORDS="*"
IUSE="apparmor"
RESTRICT="mirror"

# Kernel config checks
CONFIG_CHECK="
	~ANDROID_BINDER_IPC
	~ANDROID_BINDERFS
	~PSI
	~IP_NF_NAT
	~NETFILTER_XT_TARGET_MASQUERADE
"
ERROR_ANDROID_BINDER_IPC="CONFIG_ANDROID_BINDER_IPC is required for Waydroid"
ERROR_ANDROID_BINDERFS="CONFIG_ANDROID_BINDERFS is required for Waydroid dynamic binder node allocation"
ERROR_PSI="CONFIG_PSI is required for Android LMKD"
ERROR_IP_NF_NAT="CONFIG_IP_NF_NAT is required for Waydroid NAT networking"

RDEPEND="
	${PYTHON_DEPS}
	app-containers/lxc
	>=app-containers/waydroid-audio-hal-1.0.0
	>=app-containers/waydroid-camera-hal-fix-1.0.0
	>=app-containers/waydroid-gralloc-fix-1.0.0
	app-containers/waydroid-images
	dev-python/dbus-python[${PYTHON_USEDEP}]
	>=dev-python/python-gbinder-1.3.1[${PYTHON_USEDEP}]
	dev-python/pygobject[${PYTHON_USEDEP}]
	net-dns/dnsmasq
	>=dev-libs/libgbinder-1.1.43
"
DEPEND=""
BDEPEND=""

src_unpack() {
	default
	# NAVER BSD attribution for init.cras-audio.rc, staged at the top of
	# the work dir where the chromite license scan looks (see the LICENSE
	# comment above).
	cp "${FILESDIR}/LICENSE.whaleos" "${WORKDIR}/LICENSE.whaleos" \
		|| die "failed to stage NAVER LICENSE"
}

src_prepare() {
	default
}

src_install() {
	# USE_NFTABLES=0: iptables instead of nftables (nftables-0.8 too old).
	# USE_DBUS_ACTIVATION=0: prevent /usr/share/dbus-1/system-services/
	#   id.waydro.Container.service from being installed. That file has
	#   SystemdService=waydroid-container.service; with ChromeOS's systemd-
	#   aware dbus-daemon, any D-Bus query for id.waydro.Container would
	#   trigger systemd to start the container automatically.
	# USE_SYSTEMD=0: prevent /usr/lib/systemd/system/waydroid-container.service
	#   (WantedBy=multi-user.target) from being installed. Without this flag
	#   the unit exists on disk and systemd-activation via D-Bus could start it.
	emake DESTDIR="${D}" USE_NFTABLES=0 USE_DBUS_ACTIVATION=0 USE_SYSTEMD=0 install

	# Install Upstart services (WhaleOS-specific, not upstream)
	insinto /etc/init
	doins "${FILESDIR}/waydroid-container.conf"
	doins "${FILESDIR}/waydroid-session.conf"

	# D-Bus policy files
	insinto /etc/dbus-1/system.d
	doins "${FILESDIR}/id.waydro.Container.conf"

	# Session D-Bus policy
	insinto /etc/dbus-1/session.d
	doins "${FILESDIR}/id.waydro.Session.conf"

	# Session bus config: ANONYMOUS auth so both root and chronos can connect.
	insinto /usr/share/waydroid
	doins "${FILESDIR}/waydroid-session-bus.conf"

	# /run directories only (tmpfs); /var paths omitted to avoid SELinux
	# context failures in early-boot tmpfiles-setup.
	insinto /usr/lib/tmpfiles.d
	doins "${FILESDIR}/waydroid.conf"

	# Waydroid-only lxc-start wrapper.  The upstart jobs prepend
	# /usr/lib/waydroid/bin to PATH so Waydroid's Python helpers
	# resolve `lxc-start` to this wrapper, which file_contexts
	# labels whaleos_waydroid_exec so domain_auto_trans into the
	# whaleos_waydroid SELinux domain only fires for Waydroid
	# invocations -- not for any other lxc-start use on the host.
	exeinto /usr/lib/waydroid/bin
	doexe "${FILESDIR}/waydroid_lxc_start"
	# Rename to lxc-start so Waydroid's bare `lxc-start` PATH lookup
	# finds it.
	dosym waydroid_lxc_start /usr/lib/waydroid/bin/lxc-start

	# Pre-create waydroid work directory skeleton under /usr/local so it
	# lands on the stateful partition (dev_image) and is ready on first boot
	# without any runtime or tmpfiles.d setup.
	keepdir /usr/local/var/lib/waydroid/images
	keepdir /usr/local/var/lib/waydroid/lxc
	keepdir /usr/local/var/lib/waydroid/rootfs
	keepdir /usr/local/var/lib/waydroid/overlay
	keepdir /usr/local/var/lib/waydroid/overlay_rw
	keepdir /usr/local/var/lib/waydroid/data
	keepdir /usr/local/var/lib/lxc/rootfs

	# init.waydroid.rc: injected into the container at runtime via LXC bind-mount
	# (0009 patch) to remount /data with exec after vold mounts encstateful noexec.
	insinto /usr/lib/waydroid/data/configs
	doins "${FILESDIR}/init.waydroid.rc"

	# Android overlay: audio config files for CRAS passthrough mode.
	# Activated by 0006-cras-audio-support.patch (bind-mounted at
	# container start).  CRAS socket access is gated by the
	# `whaleos_waydroid` SELinux domain (see platform2/sepolicy/
	# policy/chromeos/whaleos_waydroid.te), which has cros_cras_client()
	# granted so the container audioserver can connect to
	# /run/cras/.cras_socket through the LXC bind-mount without the
	# host needing to be put into SELinux permissive mode.
	insinto /usr/lib/waydroid/android-overlay/vendor/etc/vintf
	doins "${FILESDIR}/android-overlay/vendor/etc/vintf/manifest.xml"
	insinto /usr/lib/waydroid/android-overlay/vendor/etc/init
	doins "${FILESDIR}/android-overlay/vendor/etc/init/android.hardware.audio.service.rc"
	insinto /usr/lib/waydroid/android-overlay/system/etc/init
	doins "${FILESDIR}/android-overlay/system/etc/init/audioserver.rc"
	doins "${FILESDIR}/android-overlay/system/etc/init/init.cras-audio.rc"

	if use apparmor; then
		insinto /etc/apparmor.d
		doins "${S}/data/configs/apparmor/lxc-waydroid"
	fi
}

pkg_postinst() {
	elog "Waydroid installed. Android images are pre-bundled."
	elog "After booting: waydroid show-full-ui"
}
