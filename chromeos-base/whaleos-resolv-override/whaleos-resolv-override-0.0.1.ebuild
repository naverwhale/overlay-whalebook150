# Copyright 2026 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=7

DESCRIPTION="Bypass dns-proxy stub on WhaleOS: point /etc/resolv.conf at shill directly"

LICENSE="BSD"
SLOT="0"
KEYWORDS="-* amd64 x86"
IUSE=""
S="${WORKDIR}"

# We rewrite the same symlink that chromeos-base/dns-proxy installs, so
# make sure dns-proxy has already run its src_install by the time our
# pkg_postinst fires.  Caveat: this RDEPEND only guarantees the *first*
# merge order.  The override symlink is written by pkg_postinst and
# never recorded in the VDB CONTENTS, so:
#   - portage cannot track or clean it up (bypasses collision-protect).
#   - re-emerging chromeos-base/dns-proxy on a dev sysroot silently
#     restores its own symlink and reverts this workaround.  Fresh
#     build_image runs are fine (they merge in dependency order), but
#     `cros deploy` / `emerge-<board> dns-proxy` on a live tree is not.
RDEPEND="chromeos-base/dns-proxy"
DEPEND=""

# Why this package exists:
#
# In R150 the shill upstart rule gained a `started wpasupplicant`
# dependency, which reorders shill against dns-proxy on WhaleOS boards.
# The result is a two-layer race in dns-proxy:
#   1. `Proxy::OnShillReady` fires when shill registers its D-Bus name,
#      but shill still hasn't finished device probe and default-service
#      selection at that instant, so shill_->DefaultDevice() returns
#      "No devices found" (shill/dbus/client/client.cc:845).
#   2. Once shill picks a default service, the DefaultDeviceChanged
#      signal never reaches the dns-proxy subscribers registered
#      before that point.  Every 127.0.0.2 DNS query then times out
#      because dns-proxy has no upstream, and Chrome's OOBE web view
#      cannot resolve account.whalespace.io / oauth.whale.naver.com,
#      so the user is stuck on the login screen.
#
# `initctl restart ui` masks the bug because chrome forces shill to
# reselect the default service, which re-emits the signal.  On cold
# boot there is nothing to trigger that.
#
# The proper fix belongs in dns-proxy / shill dbus client, but that
# lives in shared platform2 and needs an upstream cros discussion.
# Meanwhile we make dns-proxy irrelevant to WhaleOS boot by pointing
# /etc/resolv.conf straight at shill's own resolv.conf.  Chrome then
# reads the real upstream nameservers assigned by DHCP and DNS works
# regardless of dns-proxy's state.

pkg_postinst() {
	# Rewrite the /etc/resolv.conf symlink that chromeos-base/dns-proxy
	# just installed.  pkg_postinst runs against ${EROOT}, so this
	# modifies the target board image (not the build host).
	#
	# Refuse to touch the host root: an unprotected ${EROOT%/} would
	# expand to empty when EROOT=/ (e.g. someone runs `emerge` inside
	# the SDK by accident) and clobber the builder's own resolv.conf,
	# instantly killing SDK networking.  KEYWORDS gate does not cover
	# every path that can reach this.
	if [[ -z "${EROOT%/}" ]]; then
		die "refusing to rewrite the host /etc/resolv.conf (EROOT=/)"
	fi
	local resolv="${EROOT%/}/etc/resolv.conf"
	# Use ewarn on failure rather than die: `cros deploy` lands on a
	# read-only rootfs where `ln` fails, and killing the whole postinst
	# there would break deploys without undoing the merge that already
	# happened.  The build_image path always runs against a writable
	# staging root, so a real failure there is still surfaced loudly.
	if ! ln -sfn /run/shill/resolv.conf "${resolv}"; then
		ewarn "Failed to override ${resolv} (rootfs read-only?)"
		return
	fi
	elog "Redirected /etc/resolv.conf -> /run/shill/resolv.conf"
	elog "to work around dns-proxy startup race on WhaleOS boards."
}

src_unpack() {
	default
	mkdir -p "${S}" || die
	cp "${FILESDIR}/LICENSE" "${WORKDIR}/LICENSE" || die "failed to stage LICENSE"
}
