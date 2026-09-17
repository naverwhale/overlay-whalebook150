# Copyright 2014 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="2b0804f9eae0957fc18cb50197b134a6c2dbb2b3"
CROS_WORKON_TREE=(
	"518b50f8b6d01e95cbd933487ed7c6452ac4acb3"  # common-mk
	"dd2fad2176ff8c02ae553e5a695b908e2ca4fe71"  # chaps
	"16839d1d0fcecb39e52d1bc3a65aa02d62c1ee6d"  # chromeos-config
	"55903d6d672e8bdad40486765d522b08aa485668"  # libpasswordprovider
	"563a31cc4efc68801a445225fd7c6c110280d904"  # metrics
	"4a66dcc3a24bb1d8ad724e74bfb423c3eb78046b"  # shill
	"f91b6afd5f2ae04ee9a2c19109a3a4a36f7659e6"  # .gn
	"43eb4f30218ee6fc055f185786d914bccd668086"  # mojo_service_manager
)
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_DESTDIR="${S}/platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
# TODO(crbug.com/809389): Avoid directly including headers from other packages.
CROS_WORKON_SUBTREE="common-mk chaps chromeos-config libpasswordprovider metrics shill .gn mojo_service_manager"

# b/445166440: Work around test failures.
CROS_SANITIZER_DISABLE_UBSAN_VPTR=1

PLATFORM_SUBDIR="shill"
# Do not run test parallelly for shill. See b/293995835.
# shellcheck disable=SC2034
PLATFORM_PARALLEL_GTEST_TEST="no"

inherit cros-sanitizers cros-workon platform cros-protobuf systemd tmpfiles udev user

DESCRIPTION="Shill Connection Manager for Chromium OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/shill/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="cellular fuzzer systemd +tpm +vpn +wake_on_wifi +wpa3_sae system_wide_scudo"

# Sorted by the package we depend on. (Not by use flag!)
COMMON_DEPEND="
	chromeos-base/bootstat:=
	chromeos-base/chaps:=
	chromeos-base/chromeos-config-tools:=
	chromeos-base/debugd-client:=
	chromeos-base/minijail:=
	chromeos-base/net-base:=
	chromeos-base/libpasswordprovider:=
	>=chromeos-base/metrics-0.0.1-r3152:=
	chromeos-base/mojo_service_manager:=
	chromeos-base/nsswitch:=
	chromeos-base/patchpanel-client:=
	dev-libs/re2:=
	cellular? ( net-dialup/ppp:= )
	vpn? ( net-dialup/ppp:= )
	net-dns/c-ares:=
	virtual/wpa_supplicant
	sys-apps/dbus:=
	sys-apps/rootdev:=
	sys-apps/util-linux:=
"

RDEPEND="${COMMON_DEPEND}
	net-misc/dhcpcd-legacy
	net-misc/dhcpcd
	vpn? ( net-dialup/xl2tpd:= )
	vpn? ( net-vpn/openvpn )
	vpn? ( net-vpn/strongswan:= )
	vpn? ( net-vpn/wireguard-tools )
	cellular? ( net-misc/modemmanager-next:= )
"
DEPEND="${COMMON_DEPEND}
	chromeos-base/shill-client:=
	chromeos-base/power_manager-client:=
	chromeos-base/system_api:=[fuzzer?]
	net-misc/modemmanager-next:=
"
PDEPEND="chromeos-base/patchpanel"

BDEPEND="
	chromeos-base/chromeos-dbus-bindings
"

pkg_setup() {
	enewgroup "shill"
	enewuser "shill"
	cros-workon_pkg_setup
}

pkg_preinst() {
	enewgroup "shill-scripts"
	enewuser "shill-scripts"
	enewgroup "nfqueue"
	enewuser "nfqueue"
	enewgroup "vpn"
	enewuser "vpn"
}

get_dependent_services() {
	local dependent_services=()
	dependent_services+=(wpasupplicant)
	if use systemd; then
		echo "network-services.service ${dependent_services[*]/%/.service }"
	else
		echo "started network-services " \
			"${dependent_services[*]/#/and started }"
	fi
}

src_configure() {
	cros_optimize_package_for_speed
	platform_src_configure
}

src_install() {
	platform_src_install

	dobin bin/ff_debug

	dobin bin/set_arpgw
	dobin bin/set_wake_on_lan
	dobin bin/shill_login_user
	dobin bin/shill_logout_user
	dobin bin/wpa_debug
	dobin "${OUT}"/shill

	local shims_dir=/usr/$(get_libdir)/shill/shims
	exeinto "${shims_dir}"

	use vpn && doexe "${OUT}"/openvpn-script
	if use cellular || use vpn; then
		newexe "${OUT}"/lib/libshill-pppd-plugin.so shill-pppd-plugin.so
	fi

	sed \
		"s,@libdir@,/usr/$(get_libdir)", \
		shims/wpa_supplicant.conf.in \
		> "${D}/${shims_dir}/wpa_supplicant.conf"

	insinto /etc/dbus-1/system.d
	doins shims/org.chromium.flimflam.conf

	if use cellular; then
		insinto /usr/share/shill
		doins "${OUT}"/serviceproviders.pbf
		insinto /usr/share/protofiles
		doins "${S}/mobile_operator_db/mobile_operator_db.proto"
	fi

	# Install introspection XML
	insinto /usr/share/dbus-1/interfaces
	doins dbus_bindings/org.chromium.flimflam.*.dbus-xml
	doins dbus_bindings/dbus-service-config.json

	# Replace template parameters inside init scripts
	local shill_name="shill.$(usex systemd service conf)"
	sed \
		"s,@expected_started_services@,$(get_dependent_services)," \
		"init/${shill_name}.in" \
		> "${T}/${shill_name}"

	# Install init scripts
	if use systemd; then
		systemd_dounit init/shill-start-user-session.service
		systemd_dounit init/shill-stop-user-session.service

		local dependent_services
		dependent_services=$(get_dependent_services) # ShellCheck gets confused if these lines are merged as local dependent_services=$(get_dependent_services)
		systemd_dounit "${T}/shill.service"
		for dependent_service in ${dependent_services}; do
			systemd_enable_service "${dependent_service}" shill.service
		done
		systemd_enable_service shill.service network.target

		systemd_dounit init/network-services.service
		systemd_enable_service boot-services.target network-services.service
	else
		insinto /etc/init

		doins "${T}"/*.conf
		doins \
			init/network-services.conf \
			init/shill-event.conf \
			init/shill-start-user-session.conf \
			init/shill-stop-user-session.conf \
			init/shill_respawn.conf
	fi
	exeinto /usr/share/cros/init
	doexe init/*.sh
	dotmpfiles tmpfiles.d/*.conf

	insinto /usr/share/cros/startup/process_management_policies
	doins setuid_restrictions/shill_uid_allowlist.txt

	# Shill keeps profiles inside the user's cryptohome.
	local daemon_store="/etc/daemon-store/shill"
	dodir "${daemon_store}"
	fperms 0700 "${daemon_store}"
	fowners shill:shill "${daemon_store}"

	local cellular_fuzzer_component_id="167157"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/cellular_pco_fuzzer" \
		--comp "${cellular_fuzzer_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/verizon_subscription_state_fuzzer" \
		--comp "${cellular_fuzzer_component_id}"

	local wifi_fuzzer_component_id="893827"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/nl80211_message_fuzzer" \
		--comp "${wifi_fuzzer_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/wifi_ies_fuzzer" \
		--comp "${wifi_fuzzer_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/wifi_service_fuzzer" \
		--comp "${wifi_fuzzer_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/wifi_anqp_fuzzer" \
		--comp "${wifi_fuzzer_component_id}"

	local chromeos_platform_connectivity_network_component_id="167325"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/dhcpv4_static_routes_fuzzer" \
		--comp "${chromeos_platform_connectivity_network_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/shill_profile_fuzzer" \
		--comp "${chromeos_platform_connectivity_network_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/shill_service_fuzzer" \
		--comp "${chromeos_platform_connectivity_network_component_id}"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}/shill_technology_fuzzer" \
		--comp "${chromeos_platform_connectivity_network_component_id}"

	if use vpn; then
		local vpn_fuzzer_component_id="1493959"
		platform_fuzzer_install "${S}"/OWNERS "${OUT}/openvpn_management_server_fuzzer" \
			--comp "${vpn_fuzzer_component_id}"
		platform_fuzzer_install "${S}"/OWNERS "${OUT}/vpn_ipsec_connection_fuzzer" \
			--comp "${vpn_fuzzer_component_id}"
	fi
}

WHALEOS_PATCHES=(
	"${FILESDIR}/whaleos-shill.patch"
	"${FILESDIR}/whaleos-chaps.patch"
)

src_prepare() {
	local platform2_root="${S%/${PLATFORM_SUBDIR}}"
	pushd "${platform2_root}" > /dev/null || die
	local p; for p in "${WHALEOS_PATCHES[@]}"; do
		git apply --no-index -p1 "${p}" || die "git apply failed: ${p}"
	done
	popd > /dev/null || die
	default
}
