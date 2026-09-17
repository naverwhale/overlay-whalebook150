# Copyright 2022-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit bash-completion-r1 linux-info meson optfeature systemd cros-toolchain-funcs verify-sig

PATCHES=(
	"${FILESDIR}/0001-cpuset-noprefix-fallback.patch"
	# NOTE: 0002 / 0003 ELOOP-fallback patches are intentionally
	# dropped.  They worked around chromiumos LSM rejecting mount
	# targets that traversed a symlink (incl. /proc/self/fd/<n>),
	# but the proper fix landed kernel-side -- our chromiumos LSM
	# patch (commit 2b0ea8c55a57 + 3dc27bbc8471 on third_party/
	# kernel/v5.15) now lets CAP_SYS_ADMIN callers cross symlinks
	# in sb_mount, so the LXC userspace fallback is no longer
	# reachable and the previous fallback's TOCTOU concern goes
	# away with it.
)

DESCRIPTION="A userspace interface for the Linux kernel containment features"
HOMEPAGE="https://linuxcontainers.org/ https://github.com/lxc/lxc"
SRC_URI="https://linuxcontainers.org/downloads/lxc/${P}.tar.gz
	verify-sig? ( https://linuxcontainers.org/downloads/lxc/${P}.tar.gz.asc )"

LICENSE="GPL-2 LGPL-2.1 LGPL-3"
SLOT="5" # SONAME liblxc.so.1 + ${PV//./} _if_ breaking ABI change while bumping.
KEYWORDS="*"
IUSE="apparmor +caps examples io-uring lto man pam seccomp selinux ssl systemd test +tools"

RDEPEND="apparmor? ( sys-libs/libapparmor )
	caps? ( sys-libs/libcap )
	io-uring? ( >=sys-libs/liburing-2:= )
	pam? ( sys-libs/pam )
	seccomp? ( sys-libs/libseccomp )
	selinux? ( sys-libs/libselinux )
	ssl? ( dev-libs/openssl:0= )
	systemd? ( sys-apps/systemd:= )
	tools? ( sys-libs/libcap )
	!app-emulation/lxc"
DEPEND="${RDEPEND}
	sys-kernel/linux-headers"
BDEPEND="virtual/pkgconfig
	man? ( app-text/docbook2X )
	verify-sig? ( sec-keys/openpgp-keys-linuxcontainers )"

RESTRICT="!test? ( test )"

CONFIG_CHECK="~!NETPRIO_CGROUP
	~CGROUPS
	~CGROUP_CPUACCT
	~CGROUP_DEVICE
	~CGROUP_FREEZER

	~CGROUP_SCHED
	~CPUSETS
	~IPC_NS
	~MACVLAN

	~MEMCG
	~NAMESPACES
	~NET_NS
	~PID_NS

	~POSIX_MQUEUE
	~USER_NS
	~UTS_NS
	~VETH"

export ERROR_CGROUP_FREEZER="CONFIG_CGROUP_FREEZER: needed to freeze containers"
export ERROR_MACVLAN="CONFIG_MACVLAN: needed for internal (inter-container) networking"
export ERROR_MEMCG="CONFIG_MEMCG: needed for memory resource control in containers"
export ERROR_NET_NS="CONFIG_NET_NS: needed for unshared network"
export ERROR_POSIX_MQUEUE="CONFIG_POSIX_MQUEUE: needed for lxc-execute command"
export ERROR_UTS_NS="CONFIG_UTS_NS: needed to unshare hostnames and uname info"
export ERROR_VETH="CONFIG_VETH: needed for internal (host-to-container) networking"

VERIFY_SIG_OPENPGP_KEY_PATH=${BROOT}/usr/share/openpgp-keys/linuxcontainers.asc

DOCS=( AUTHORS CONTRIBUTING MAINTAINERS README.md doc/FAQ.txt )

pkg_setup() {
	linux-info_pkg_setup
}

src_configure() {
	local emesonargs=(
		--localstatedir "${EPREFIX}/var"

		-Dcoverity-build=false
		-Doss-fuzz=false

		-Dcommands=true
		-Dmemfd-rexec=false
		-Dthread-safety=true

		$(meson_use apparmor)
		$(meson_use caps capabilities)
		$(meson_use examples)
		$(meson_use io-uring io-uring-event-loop)
		$(meson_use lto b_lto)
		$(meson_use man)
		$(meson_use pam pam-cgroup)
		$(meson_use seccomp)
		$(meson_use selinux)
		$(meson_use ssl openssl)
		$(meson_use test tests)
		$(meson_use tools)

		-Ddata-path="${EPREFIX}/var/lib/lxc"
		-Ddoc-path="${EPREFIX}/usr/share/doc/${PF}"
		-Dlog-path="${EPREFIX}/var/log/lxc"
		-Ddistrosysconfdir="${EPREFIX}/etc/default"
		-Drootfs-mount-path="${EPREFIX}/var/lib/lxc/rootfs"
		-Druntime-path=/run
	)

	if use systemd; then
		local emesonargs+=( -Dinit-script="systemd" )
		local emesonargs+=( -Dsd-bus=enabled )
	else
		local emesonargs+=( -Dinit-script="sysvinit" )
		local emesonargs+=( -Dsd-bus=disabled )
	fi

	use tools && local emesonargs+=( -Dcapabilities=true )

	if tc-ld-is-gold || tc-ld-is-lld; then
		local emesonargs+=( -Db_lto_mode=thin )
	else
		local emesonargs+=( -Db_lto_mode=default )
	fi

	meson_src_configure
}

src_install() {
	meson_src_install

	# The main bash-completion file will collide with lxd, need to relocate and update symlinks.
	mkdir -p "${ED}/$(get_bashcompdir)" || die "Failed to create bashcompdir."

	if use tools; then
		bashcomp_alias lxc-start lxc-{attach,autostart,cgroup,checkpoint,config,console,copy,create,destroy,device,execute,freeze,info,ls,monitor,snapshot,stop,top,unfreeze,unshare,usernsexec,wait}
	else
		bashcomp_alias lxc-start lxc-usernsexec
	fi

	keepdir /var/lib/cache/lxc /var/lib/lib/lxc

	find "${ED}" -name '*.la' -delete -o -name '*.a' -delete || die
}

pkg_postinst() {
	elog "Please refer to "
	elog "https://wiki.gentoo.org/wiki/LXC for introduction and usage guide."
	elog
	elog "Run 'lxc-checkconfig' to see optional kernel features."
	elog

	optfeature "automatic template scripts" app-containers/lxc-templates
	optfeature "Debian-based distribution container image support" dev-util/debootstrap
	optfeature "snapshot & restore functionality" sys-process/criu
}
