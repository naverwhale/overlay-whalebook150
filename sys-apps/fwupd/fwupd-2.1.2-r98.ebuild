# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="e44623586958575e8cb2c60c16ff7264932cad12"
CROS_WORKON_TREE="5b18dd908fea6442ccc0f7741b3b4a937d7b84db"
PYTHON_COMPAT=( python3_11 )

CROS_WORKON_PROJECT="chromiumos/third_party/fwupd"
CROS_WORKON_EGIT_BRANCH="fwupd-2.1.2"

inherit python-any-r1 cros-workon linux-info meson udev user cros-sanitizers

DESCRIPTION="Aims to make updating firmware on Linux automatic, safe and reliable"
HOMEPAGE="https://fwupd.org"
#SRC_URI="https://github.com/${PN}/${PN}/releases/download/${PV}/${P}.tar.xz"

LICENSE="LGPL-2.1+"
SLOT="0"
KEYWORDS="*"
# The config file gets installed to /etc/fwupd/fwupd.conf
CONFIG_FILE="fwupd.conf"

if [[ ${PV} == "9998" ]] ; then
	EGIT_REPO_URI="https://github.com/fwupd/fwupd"
	EGIT_BRANCH="main"
	inherit git-r3
	# shellcheck disable=SC5000 # This is only for the non-cros-workon 9998
	# revision, not for a true cros-workon.
	KEYWORDS="*"
fi

IUSE="agent amt bash-completion bluetooth cfm dell fastboot flashrom +gnutls gtk-doc +gpg gpio introspection logitech minimal -modemmanager nvme nls pkcs7 policykit readline +sqlite systemd test uefi ufs"
[[ ${PV} != "9998" ]] && IUSE+=" +archive"

REQUIRED_USE="
	dell? ( uefi )
	minimal? ( !introspection )
	uefi? ( gnutls )
"

USER_DEPS="
	acct-user/chronos
	acct-user/fwupd
	acct-group/fwupd
	acct-user/cros_healthd
	acct-user/cfm-firmware-updaters
"

# shellcheck disable=SC2016
BDEPEND="
	app-arch/gcab
	dev-libs/glib
	>=dev-build/meson-1.3.2
	virtual/pkgconfig
	gtk-doc? ( >=dev-util/gi-docgen-2021.1 )
	bash-completion? ( >=app-shells/bash-completion-2.0 )
	introspection? ( dev-libs/gobject-introspection )
	$(python_gen_any_dep '
		dev-python/jinja2[${PYTHON_USEDEP}]
	')
	sys-apps/lshw
	sys-devel/gettext
	${USER_DEPS}
"
COMMON_DEPEND="
	sys-libs/zlib
	>=app-arch/gcab-1.0
	app-arch/xz-utils
	dev-db/sqlite:3
	>=dev-libs/glib-2.68:2
	>=dev-libs/json-glib-1.6.0
	>=dev-libs/libjcat-0.2.0[gpg?,pkcs7?]
	>=dev-libs/libusb-1.0.27
	>=dev-libs/libxmlb-0.3.19:=[introspection?]
	net-libs/libmnl:=
	>=net-misc/curl-7.62.0
	>=sys-libs/zlib-1.2.13
	sys-apps/util-linux

	dell? (
		>=app-crypt/tpm2-tss-2.0
		>=sys-libs/libsmbios-2.4.0
	)
	flashrom? ( sys-apps/flashrom )
	gnutls? ( >=net-libs/gnutls-3.6.0 )
	modemmanager? ( net-misc/modemmanager[mbim,qmi] )
	policykit? ( >=sys-auth/polkit-0.114 )
	readline? ( sys-libs/readline:= )
	net-libs/libmnl:=
	systemd? ( >=sys-apps/systemd-249:= )
	uefi? (
		sys-apps/fwupd-efi
		sys-boot/efibootmgr
		sys-libs/efivar
	)
"

RDEPEND="
	${COMMON_DEPEND}
	${USER_DEPS}
	uefi? ( chromeos-base/mini_udisks )
	sys-apps/dbus
"

DEPEND="
	${COMMON_DEPEND}
	x11-libs/pango[introspection?]
	sys-kernel/linux-headers
"

pkg_setup() {
	if use nvme ; then
		kernel_is -ge 4 4 || die "NVMe support requires kernel >= 4.4"
	fi
}

src_prepare() {
	default
	# c.f. https://github.com/fwupd/fwupd/issues/1414
	sed -e "/test('thunderbolt-self-test', e, env: test_env, timeout : 120)/d" \
		-i plugins/thunderbolt/meson.build || die

	sed -i -e "/install_dir.*'doc'/s/doc/gtk-doc/" \
		 docs/meson.build || die

	if ! use nls ; then
		echo > po/LINGUAS || die
	fi
}

src_configure() {
	sanitizers-setup-env

	# fwupd's unittests aren't compatible with `-fsanitize=function`.
	# This can be removed once https://github.com/fwupd/fwupd/pull/9216
	# lands and is integrated.
	use ubsan && append-cflags "-fno-sanitize=function"

	local plugins=(
		# TODO(b/276484917): the splash feature doesn't build
		# successfully yet.
		-Dplugin_uefi_capsule_splash="false"
		$(meson_feature flashrom plugin_flashrom)
		$(meson_feature modemmanager plugin_modem_manager)
	)

	if use cfm; then
		plugins+=(
			# Logitech bulkcontroller
			# Note: Logitech Scribe and TAP plugins are now enabled
			# by default on Linux systems. See the src_install function
			# below for how we disable explicitly in non-cfm builds.
		)
	fi

	local emesonargs=(
		--localstatedir "${EPREFIX}"/var
		-Dauto_features="disabled"
		-Dbuild="$(usex minimal standalone all)"
		-Dblkid=enabled
		-Defi_binary="false"
		-Dman="true"
		-Dsupported_build="enabled"
		$(meson_use bash-completion bash_completion)
		$(meson_feature bluetooth bluez)
		$(meson_feature gnutls)
		$(meson_feature gtk-doc docs)
		$(meson_feature introspection)
		$(meson_feature policykit polkit)
		$(meson_feature readline)
		$(meson_feature systemd)
		$(meson_use test tests)

		"${plugins[@]}"
	)

	use uefi && emesonargs+=( -Defi_os_dir="chromeos" )
	export CACHE_DIRECTORY="${T}"
	meson_src_configure
}

src_test() {
	# TODO(rishabhagr): Remove temporary fix after https://github.com/fwupd/fwupd/issues/8466 is fixed
	# TODO(b/430118754): uefi-dbx-self-test has been temporarily removed
	# from this list due to flakiness.
	local test_args=()
	mapfile -t test_args < <(meson test --list -C "${BUILD_DIR}" | grep -vE 'uefi-dbx-self-test|fwupd-client-test|fwupd-self-test|snap-self-test|uefi-self-test|fu-engine-udev-test' | grep -v 'No tests defined')
	if [[ ${#test_args[@]} -gt 0 ]]; then
		LC_ALL="C.UTF-8" meson_src_test "${test_args[@]}"
	else
		einfo "No tests to run."
	fi
}

src_install() {
	meson_src_install

	# Fix generated file user permissions.
	sudo chown -R fwupd "${ED}"/etc/fwupd || die

	# Add the local mirror as base url
	local local_mirror_url="https://storage.googleapis.com/chromeos-localmirror/lvfs/"
	echo "FirmwareBaseURI=${local_mirror_url}" >> "${ED}"/etc/${PN}/remotes.d/lvfs.conf || die

	# Enable vendor-directory remote with local firmware
	sed 's/Enabled=false/Enabled=true/' -i "${ED}"/etc/${PN}/remotes.d/vendor-directory.conf || die

	# Set Metadata to point to the mirror
	local uri="https://storage.googleapis.com/chromeos-localmirror/lvfs/firmware.xml.xz"
	sed 's,MetadataURI=.*,MetadataURI='"${uri}"',' -i "${ED}"/etc/${PN}/remotes.d/lvfs.conf || die

	# Allow chronos and fwupd to issue installs/updates
	# Allow cros_healthd to obtain instanceIds and serials
	local chronos_uid=$(egetent passwd chronos | cut -d: -f3)
	local cros_healthd_uid=$(egetent passwd cros_healthd | cut -d: -f3)
	local fwupd_uid=$(egetent passwd fwupd | cut -d: -f3)
	echo "TrustedUids=${chronos_uid};${cros_healthd_uid};${fwupd_uid}" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die

	# Set trusted-reports flag if Distro is chromeos and if the firmware is
	# uploaded by one of: Google, Allion or the firmware owner themselves
	local cros_distro="DistroId=chromeos"
	local google_vendorid="${cros_distro}&VendorId=16"
	local allion_vendorid="${cros_distro}&VendorId=1923&Flags=is-upgrade"
	local firmware_owner_vendorid="${cros_distro}&VendorId=\$OEM&Flags=is-upgrade"
	echo "TrustedReports=${google_vendorid};${allion_vendorid};${firmware_owner_vendorid}" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die

	# Disable all plugins we don't support on ChromeOS or those that unwantedly probe certain devices.
	local disabled_plugins="fastboot;pgio;intel_me;elogind;"
	if ! use cfm; then
		disabled_plugins="${disabled_plugins}protobuf;logitech_scribe;logitech_tap;"
	fi
	if ! use uefi; then
		disabled_plugins="${disabled_plugins}uefi_capsule;uefi_pk;"
	fi
	echo "DisabledPlugins=${disabled_plugins}" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die

	# Install udev rules to fix user permissions.
	udev_dorules "${FILESDIR}"/90-fwupd.rules

	# Change D-BUS owner for org.freedesktop.fwupd
	sed 's/root/fwupd/' -i "${ED}"/usr/share/dbus-1/system.d/org.freedesktop.fwupd.conf || die

	# Install D-BUS service for org.freedesktop.fwupd to enable D-BUS activation
	insinto /usr/share/dbus-1/system-services
	doins "${FILESDIR}"/org.freedesktop.fwupd.service

	insinto /etc/init
	# Install upstart script for fwupd daemon.
	doins "${FILESDIR}"/init/fwupd.conf
	# Install upstart script for activating firmware update on logout/shutdown.
	doins "${FILESDIR}"/init/fwupdtool-activate.conf
	# Install upstart script for automatic firmware update on device plug-in.
	doins "${FILESDIR}"/init/fwupdtool-update.conf

	insinto /usr/lib/tmpfiles.d
	# Install tmpfiles script for generating the necessary directories
	doins "${FILESDIR}"/tmpfiles.d/fwupd.conf

	insinto /usr/lib/tmpfiles.d/on-demand
	# Install tmpfiles script for removing lock files
	doins "${FILESDIR}"/tmpfiles.d/on-demand/fwupd-lock-cleanup.conf

	# Set Best Know Configuration tag to chromium (See cros-fwupd.eclass)
	echo "HostBkc=chromium" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die

	exeinto /usr/share/cros/init
	doexe "${FILESDIR}"/fwupd-at-boot.sh

	# Install rsyslog config.
	insinto /etc/rsyslog.d
	doins "${FILESDIR}"/rsyslog.fwupd.conf

	if ! use minimal ; then
		if ! use systemd ; then
			# Don't timeout when fwupd is running (#673140)
			echo "IdleTimeout=0" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die
		fi
	fi

	if use cfm ; then
		# Allow firmware from CfM mirror to be installed by fwupd
		if ! grep -q OnlyTrusted "${ED}"/etc/${PN}/${CONFIG_FILE}; then
			echo "OnlyTrusted=false" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die
		else
			sed '/^OnlyTrusted=/s/true/false/' -i "${ED}"/etc/${PN}/${CONFIG_FILE} || die
		fi
		# Allow cfm-firmware-updaters to issue installs/updates
		local cfm_firmware_updaters_uid=$(egetent passwd cfm-firmware-updaters | cut -d: -f3)
		sed "/^TrustedUids=.*/s/$/;${cfm_firmware_updaters_uid}/" -i "${ED}"/etc/${PN}/${CONFIG_FILE} || die
		# Override ArchiveSizeMax to accommodate Logitech Rally Bar, Mini
		if ! grep -q "ArchiveSizeMax=" "${ED}"/etc/${PN}/${CONFIG_FILE}; then
			echo "ArchiveSizeMax=3072000000" >> "${ED}"/etc/${PN}/${CONFIG_FILE} || die
		fi
	fi
}
