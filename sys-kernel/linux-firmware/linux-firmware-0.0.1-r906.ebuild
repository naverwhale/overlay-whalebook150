# Copyright 2013 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"
CROS_WORKON_COMMIT="ab21d2236596560005b9b5039c3e678a11ee0ee8"
CROS_WORKON_TREE="a8215e48c51d0317209402cd30fb821f8c116315"
CROS_WORKON_PROJECT="chromiumos/third_party/linux-firmware"
CROS_WORKON_OUTOFTREE_BUILD=1
CROS_WORKON_EGIT_BRANCH="master"

inherit cros-workon

DESCRIPTION="Firmware images from the upstream linux-firmware package"
HOMEPAGE="https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/"

KEYWORDS="*"


IUSE_KERNEL_VERS=(
	kernel-5_4
	kernel-5_10
	kernel-5_15
	kernel-6_1
	kernel-6_6
	kernel-6_10-enablement
	kernel-6_12
	kernel-upstream
)
IUSE_ATH3K=(
	ath3k-all
	ath3k-ar3011
	ath3k-ar3012
)
IUSE_IWLWIFI=(
	iwlwifi-all
	iwlwifi-lg14u390
	iwlwifi-100
	iwlwifi-105
	iwlwifi-135
	iwlwifi-1000
	iwlwifi-1000
	iwlwifi-2000
	iwlwifi-2030
	iwlwifi-3160
	iwlwifi-3945
	iwlwifi-4965
	iwlwifi-5000
	iwlwifi-5150
	iwlwifi-6000
	iwlwifi-6005
	iwlwifi-6030
	iwlwifi-6050
	iwlwifi-7260
	iwlwifi-7265
	iwlwifi-7265D
	iwlwifi-9000
	iwlwifi-9260
	iwlwifi-cc
	iwlwifi-gl
	iwlwifi-ma
	iwlwifi-QuZ
	iwlwifi-so
	iwlwifi-so-a0-hr
)
IUSE_BRCMWIFI=(
	brcmfmac-all
	brcmfmac4354-sdio
	brcmfmac4356-pcie
	brcmfmac4371-pcie
)
IUSE_LINUX_FIRMWARE=(
	adreno-630
	adreno-660
	adsp_apl
	adsp_cnl
	adsp_glk
	adsp_kbl
	adsp_skl
	ath9k_htc
	ath10k_qca6174a-5
	ath10k_qca6174a-3
	ath10k_wcn3990
	ath11k_wcn6750
	ath11k_wcn6855
	amd_ucode
	amdgpu_gc_11_0_1
	amdgpu_gc_11_0_4
	amdgpu_yellow_carp
	bcm4354-bt
	cros-pd
	fw_sst
	fw_sst2
	i915_adl
	i915_cnl
	i915_glk
	i915_mtl
	i915_skl
	i915_tgl
	ibt_9260
	ibt_9462
	ibt_9560
	ibt_ax200
	ibt_ax201
	ibt_ax203
	ibt_ax210
	ibt_ax211
	ibt_ax211_mtl
	ibt_be200
	ibt-hw
	ibt-sec
	ice
	ipu3_fw
	ipu6_fw
	keyspan_usb
	marvell-mwlwifi
	marvell-pcie8897
	marvell-pcie8997
	mt7920
	mt7920-bt
	mt7921e
	mt7921e-bt
	mt7922
	mt7922-bt
	mt7925
	mt7925-bt
	mt8173-vpu
	nvidia-xusb
	nxp_uwb_sr150
	qca6174a-3-bt
	qca6174a-5-bt
	qca-wcn3990-bt
	qca-wcn3991-bt
	qca-wcn685x-bt
	qca-wcn6750-bt
	rockchip-dptx
	rt2870
	rtl8107e-1
	rtl8107e-2
	rtl8125a-3
	rtl8125b-1
	rtl8125b-2
	rtl8153
	rtl8168fp-3
	rtl8168g-1
	rtl8168g-2
	rtl8168h-1
	rtl8168h-2
	rtl_bt-8822ce-uart
	rtl_bt-8822ce-usb
	rtl_bt-8852ae-usb
	rtl_bt-8852be-usb
	rtl_bt-8852be-vt-usb
	rtl_bt-8852ce-usb
	rtw8821c
	rtw8822b
	rtw8822c
	rtw8852a
	rtw8852b
	rtw8852c
	venus-52
	venus-54
	venus-vpu-2
	"${IUSE_ATH3K[@]}"
	"${IUSE_IWLWIFI[@]}"
	"${IUSE_BRCMWIFI[@]}"
)
IUSE="
	${IUSE_KERNEL_VERS[*]}
	${IUSE_LINUX_FIRMWARE[*]/#/linux_firmware_}
	video_cards_radeon
	video_cards_amdgpu"
REQUIRED_USE="?? ( ${IUSE_KERNEL_VERS[*]} )"
LICENSE="
	linux_firmware_adreno-630? ( LICENSE.qcom )
	linux_firmware_adreno-660? ( LICENSE.qcom )
	linux_firmware_adsp_apl? ( LICENCE.adsp_sst )
	linux_firmware_adsp_cnl? ( LICENCE.adsp_sst )
	linux_firmware_adsp_glk? ( LICENCE.adsp_sst )
	linux_firmware_adsp_kbl? ( LICENCE.adsp_sst )
	linux_firmware_adsp_skl? ( LICENCE.adsp_sst )
	linux_firmware_amd_ucode? ( LICENSE.amd-ucode )
	linux_firmware_amdgpu_gc_11_0_1? ( LICENSE.amdgpu )
	linux_firmware_amdgpu_gc_11_0_4? ( LICENSE.amdgpu )
	linux_firmware_amdgpu_yellow_carp? ( LICENSE.amdgpu )
	linux_firmware_ath3k-all? ( LICENCE.atheros_firmware )
	linux_firmware_ath3k-ar3011? ( LICENCE.atheros_firmware )
	linux_firmware_ath3k-ar3012? ( LICENCE.atheros_firmware )
	linux_firmware_ath9k_htc? ( LICENCE.atheros_firmware )
	linux_firmware_ath10k_qca6174a-5? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_ath10k_qca6174a-3? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_ath10k_wcn3990? ( LICENCE.atheros_firmware )
	linux_firmware_ath11k_wcn6750? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_ath11k_wcn6855? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_bcm4354-bt? ( LICENCE.broadcom_bcm43xx )
	linux_firmware_cros-pd? ( BSD-Google )
	linux_firmware_fw_sst? ( LICENCE.fw_sst )
	linux_firmware_fw_sst2? ( LICENCE.IntcSST2 )
	linux_firmware_i915_adl? ( LICENSE.i915 )
	linux_firmware_i915_cnl? ( LICENSE.i915 )
	linux_firmware_i915_glk? ( LICENSE.i915 )
	linux_firmware_i915_mtl? ( LICENSE.i915 )
	linux_firmware_i915_skl? ( LICENSE.i915 )
	linux_firmware_i915_tgl? ( LICENSE.i915 )
	linux_firmware_ipu3_fw? ( LICENSE.ipu3_firmware )
	linux_firmware_ipu6_fw? ( BSD-Intel+patent-grant )
	linux_firmware_ibt_9260? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_9462? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_9560? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_ax200? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_ax201? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_ax203? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_ax210? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_ax211? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_ax211_mtl? ( LICENCE.ibt_firmware )
	linux_firmware_ibt_be200? ( LICENCE.ibt_firmware )
	linux_firmware_ibt-hw? ( LICENCE.ibt_firmware )
	linux_firmware_ice? ( LICENSE.ice )
	linux_firmware_keyspan_usb? ( LICENSE.keyspan_usb )
	linux_firmware_marvell-mwlwifi? ( LICENCE.Marvell )
	linux_firmware_marvell-pcie8897? ( LICENCE.NXP )
	linux_firmware_marvell-pcie8997? ( LICENCE.NXP )
	linux_firmware_mt7920? ( LICENCE.mediatek-nic )
	linux_firmware_mt7920-bt? ( LICENCE.mediatek-nic )
	linux_firmware_mt7921e? ( LICENCE.mediatek-nic )
	linux_firmware_mt7921e-bt? ( LICENCE.mediatek-nic )
	linux_firmware_mt7922? ( LICENCE.mediatek-nic )
	linux_firmware_mt7922-bt? ( LICENCE.mediatek-nic )
	linux_firmware_mt7925? ( LICENCE.mediatek-nic )
	linux_firmware_mt7925-bt? ( LICENCE.mediatek-nic )
	linux_firmware_mt8173-vpu? ( LICENCE.mediatek-vpu )
	linux_firmware_nvidia-xusb? ( LICENCE.nvidia )
	linux_firmware_nxp_uwb_sr150? ( LICENSE.nxp )
	linux_firmware_qca6174a-3-bt? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_qca6174a-5-bt? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_qca-wcn3990-bt? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_qca-wcn3991-bt? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_qca-wcn685x-bt? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_qca-wcn6750-bt? ( LICENSE.QualcommAtheros_ath10k )
	linux_firmware_rockchip-dptx? ( LICENCE.rockchip )
	linux_firmware_rt2870? ( LICENCE.ralink-firmware.txt LICENCE.ralink_a_mediatek_company_firmware )
	linux_firmware_rtl8107e-1? ( LICENCE.rtl_nic )
	linux_firmware_rtl8107e-2? ( LICENCE.rtl_nic )
	linux_firmware_rtl8125a-3? ( LICENCE.rtl_nic )
	linux_firmware_rtl8125b-1? ( LICENCE.rtl_nic )
	linux_firmware_rtl8125b-2? ( LICENCE.rtl_nic )
	linux_firmware_rtl8153? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtl8168fp-3? ( LICENCE.rtl_nic )
	linux_firmware_rtl8168g-1? ( LICENCE.rtl_nic )
	linux_firmware_rtl8168g-2? ( LICENCE.rtl_nic )
	linux_firmware_rtl8168h-1? ( LICENCE.rtl_nic )
	linux_firmware_rtl8168h-2? ( LICENCE.rtl_nic )
	linux_firmware_rtl_bt-8822ce-uart? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtl_bt-8822ce-usb? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtl_bt-8852ae-usb? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtl_bt-8852be-usb? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtl_bt-8852be-vt-usb? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtl_bt-8852ce-usb? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtw8821c? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtw8822b? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtw8822c? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtw8852a? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtw8852b? ( LICENCE.rtlwifi_firmware )
	linux_firmware_rtw8852c? ( LICENCE.rtlwifi_firmware )
	linux_firmware_venus-52? ( LICENSE.qcom )
	linux_firmware_venus-54? ( LICENSE.qcom )
	linux_firmware_venus-vpu-2? ( LICENSE.qcom )
	$(printf 'linux_firmware_%s? ( LICENCE.iwlwifi_firmware ) ' "${IUSE_IWLWIFI[@]}")
	$(printf 'linux_firmware_%s? ( LICENCE.broadcom_bcm43xx ) ' "${IUSE_BRCMWIFI[@]}")
	video_cards_radeon? ( LICENSE.radeon )
	video_cards_amdgpu? ( LICENSE.amdgpu )
"

BDEPEND="
	dev-lang/python
	dev-vcs/git
"

RDEPEND="
	linux_firmware_adreno-630? ( !media-libs/a630-fw )
	linux_firmware_adreno-630? ( !media-libs/a660-fw )
	linux_firmware_ath3k-all? ( !net-wireless/ath3k )
	linux_firmware_ath3k-ar3011? ( !net-wireless/ath3k )
	linux_firmware_ath3k-ar3012? ( !net-wireless/ath3k )
	linux_firmware_marvell-pcie8897? ( !net-wireless/marvell_sd8787[pcie] )
	linux_firmware_marvell-pcie8997? ( !net-wireless/marvell_sd8787[pcie] )
	linux_firmware_mt8173-vpu? ( !media-libs/vpu-fw )
	linux_firmware_nvidia-xusb? ( !sys-kernel/xhci-firmware )
	linux_firmware_rt2870? ( !net-wireless/realtek-rt2800-firmware )
	!net-wireless/ath6k
	!net-wireless/ath10k
	!net-wireless/iwl1000-ucode
	!net-wireless/iwl2000-ucode
	!net-wireless/iwl2030-ucode
	!net-wireless/iwl3945-ucode
	!net-wireless/iwl4965-ucode
	!net-wireless/iwl5000-ucode
	!net-wireless/iwl6000-ucode
	!net-wireless/iwl6005-ucode
	!net-wireless/iwl6030-ucode
	!net-wireless/iwl6050-ucode
	!<=sys-kernel/linux-firmware-reven-post-uprev-updates-0.0.1-r9
"

RESTRICT="binchecks strip"

FIRMWARE_INSTALL_ROOT="/lib/firmware"

use_fw() {
	use "linux_firmware_$1"
}

doins_subdir() {
	# Avoid having this insinto command affecting later doins calls.
	local file
	for file in "${@}"; do
		(
		insinto "${FIRMWARE_INSTALL_ROOT}/${file%/*}"
		doins "${file}"
		)
		# Preserve the source file's timestamp to avoid triggering
		# unnecessary kernel rebuilds of builtin firmware objects for whaleos.
		touch -r "${file}" "${D}${FIRMWARE_INSTALL_ROOT}/${file}" || die
	done
}

# WhaleOS-local (b/lg14u390): the firmware set for the lg14u390 board, whose
# rootfs partition is only 2000 MiB.  That board covers several LG SKUs with
# different WiFi modules, so it cannot pin individual iwlwifi families, but
# "iwlwifi-all" costs it 171 files / 215 MiB.
#
# This is every revision the board's iwlwifi driver declares through
# MODULE_FIRMWARE, i.e. the IWL_*_UCODE_API_MAX revision of each device it
# supports.  The driver asks for exactly these names and only walks down to
# older API revisions when they are missing, so the set covers every Intel WiFi
# module the driver knows about while dropping the ~150 superseded revisions
# and the DVM-era devices this kernel no longer builds a module for
# (215 MiB -> 29 MiB of rootfs).
#
# Derived from kernel 6.6.119 (CHROMEOS_KERNEL_SPLITCONFIG=chromeos-x86_64-reven).
# Entries that upstream linux-firmware does not carry (yet) are skipped
# silently, so this list names more than gets installed.
#
# Regenerate after a kernel uprev with:
#   modinfo /build/lg14u390/lib/modules/*/kernel/drivers/net/wireless/*/iwlwifi/iwlwifi.ko* |
#       awk '$1 == "firmware:" { print $2 }' | sort -u
#
# Missing an update is not fatal - the driver falls back to older API revisions
# that are still installed - but the board then stops getting the newest ucode.
IWLWIFI_LG14U390=(
	iwlwifi-3160-17.ucode
	iwlwifi-3168-29.ucode
	iwlwifi-7260-17.ucode
	iwlwifi-7265-17.ucode
	iwlwifi-7265D-29.ucode
	iwlwifi-8000C-36.ucode
	iwlwifi-8265-36.ucode
	iwlwifi-9000-pu-b0-jf-b0-46.ucode
	iwlwifi-9260-th-b0-jf-b0-46.ucode
	iwlwifi-Qu-b0-hr-b0-77.ucode
	iwlwifi-Qu-b0-jf-b0-77.ucode
	iwlwifi-Qu-c0-hr-b0-77.ucode
	iwlwifi-QuZ-a0-hr-b0-77.ucode
	iwlwifi-QuZ-a0-jf-b0-77.ucode
	iwlwifi-br-a0-pe-a0-98.ucode
	iwlwifi-br-a0-petc-a0-98.ucode
	iwlwifi-bz-a0-fm-b0-98.ucode
	iwlwifi-bz-a0-fm-b0.pnvm
	iwlwifi-bz-a0-fm-c0-98.ucode
	iwlwifi-bz-a0-fm-c0.pnvm
	iwlwifi-bz-a0-fm4-b0-98.ucode
	iwlwifi-bz-a0-fm4-b0.pnvm
	iwlwifi-bz-a0-gf-a0-98.ucode
	iwlwifi-bz-a0-gf-a0.pnvm
	iwlwifi-bz-a0-gf4-a0-98.ucode
	iwlwifi-bz-a0-gf4-a0.pnvm
	iwlwifi-bz-a0-hr-b0-98.ucode
	iwlwifi-cc-a0-77.ucode
	iwlwifi-dr-a0-pe-a0-98.ucode
	iwlwifi-gl-b0-fm-b0-98.ucode
	iwlwifi-gl-b0-fm-b0.pnvm
	iwlwifi-gl-c0-fm-c0-98.ucode
	iwlwifi-gl-c0-fm-c0.pnvm
	iwlwifi-ma-a0-gf-a0-89.ucode
	iwlwifi-ma-a0-gf-a0.pnvm
	iwlwifi-ma-a0-gf4-a0-89.ucode
	iwlwifi-ma-a0-gf4-a0.pnvm
	iwlwifi-ma-a0-hr-b0-89.ucode
	iwlwifi-ma-b0-gf-a0-89.ucode
	iwlwifi-ma-b0-gf-a0.pnvm
	iwlwifi-ma-b0-gf4-a0-89.ucode
	iwlwifi-ma-b0-gf4-a0.pnvm
	iwlwifi-ma-b0-hr-b0-89.ucode
	iwlwifi-sc-a0-fm-b0-98.ucode
	iwlwifi-sc-a0-fm-b0.pnvm
	iwlwifi-sc-a0-fm-c0-98.ucode
	iwlwifi-sc-a0-fm-c0.pnvm
	iwlwifi-sc-a0-gf-a0-98.ucode
	iwlwifi-sc-a0-gf-a0.pnvm
	iwlwifi-sc-a0-gf4-a0-98.ucode
	iwlwifi-sc-a0-gf4-a0.pnvm
	iwlwifi-sc-a0-hr-b0-98.ucode
	iwlwifi-sc-a0-wh-a0-98.ucode
	iwlwifi-sc-a0-wh-a0.pnvm
	iwlwifi-sc2-a0-fm-c0-98.ucode
	iwlwifi-sc2-a0-fm-c0.pnvm
	iwlwifi-sc2-a0-wh-a0-98.ucode
	iwlwifi-sc2-a0-wh-a0.pnvm
	iwlwifi-sc2f-a0-fm-c0-98.ucode
	iwlwifi-sc2f-a0-fm-c0.pnvm
	iwlwifi-sc2f-a0-wh-a0-98.ucode
	iwlwifi-sc2f-a0-wh-a0.pnvm
	iwlwifi-so-a0-gf-a0-89.ucode
	iwlwifi-so-a0-gf-a0.pnvm
	iwlwifi-so-a0-hr-b0-89.ucode
	iwlwifi-so-a0-jf-b0-89.ucode
	iwlwifi-ty-a0-gf-a0-89.ucode
	iwlwifi-ty-a0-gf-a0.pnvm
)

install_iwlwifi() {
	# We do not always need to detect the kernel version when all kernels
	# have the same iwlwifi firmware version. However, this changes every so
	# often for the 2 most recent kernels during bring up, where we can
	# typically use a more recent firmware on the in-development board but
	# keep the previous version for stable boards to avoid regressions.
	# Keep the logic around to avoid having to rewrite it every single time.
	local kernel=""
	local k
	for k in "${IUSE_KERNEL_VERS[@]}"; do
		if use "${k}"; then
			kernel="${k}"
			break
		fi
	done
	if [[ -z "${kernel}" ]]; then
		einfo "No kernel USE flag set."
		einfo "Expected if all kernels have the same iwlwifi firmware."
	fi

	for x in "${IUSE_IWLWIFI[@]}"; do
		use_fw "${x}" || continue
		case "${x}" in
		iwlwifi-all)   doins iwlwifi-*.ucode iwlwifi-*.pnvm;;
		iwlwifi-lg14u390)
			local fw
			for fw in "${IWLWIFI_LG14U390[@]}"; do
				# The driver declares devices whose firmware has not
				# landed in linux-firmware yet; skip those.
				[[ -e ${fw} ]] && doins "${fw}"
			done
			;;
		iwlwifi-6005)  doins iwlwifi-6000g2a-*.ucode ;;
		iwlwifi-6030)  doins iwlwifi-6000g2b-*.ucode ;;
		iwlwifi-7260)  doins "${x}-17.ucode" ;;
		iwlwifi-7265D) doins "${x}-29.ucode" ;;
		iwlwifi-9000)  doins "${x}-pu-b0-jf-b0-46.ucode" ;;
		iwlwifi-9260)  doins "${x}-th-b0-jf-b0-46.ucode" ;;
		iwlwifi-cc)
			case "${kernel}" in
			kernel-5_15)     doins "${x}-a0-77.ucode" ;;
			kernel-upstream) doins "${x}-a0-77.ucode" ;;
			*)               doins "${x}-a0-77.ucode" ;;
			esac
			;;
		iwlwifi-gl)
			case "${kernel}" in
			kernel-6_1)      doins "${x}-c0-fm-c0-98.ucode" ;;
			kernel-6_6)      doins "${x}-c0-fm-c0-98.ucode" ;;
			*)               doins "${x}-c0-fm-c0-98.ucode" ;;
			esac
			doins "${x}-c0-fm-c0.pnvm"
			;;
		iwlwifi-ma)
			case "${kernel}" in
			kernel-6_1)      doins "${x}-b0-gf-a0-89.ucode" ;;
			*)               doins "${x}-b0-gf-a0-89.ucode" ;;
			esac
			doins "${x}-b0-gf-a0.pnvm"
			;;
		iwlwifi-QuZ)
			case "${kernel}" in
			kernel-5_4)  doins "${x}-a0-hr-b0-77.ucode" ;;
			kernel-5_10) doins "${x}-a0-hr-b0-77.ucode" ;;
			kernel-5_15) doins "${x}-a0-hr-b0-77.ucode" ;;
			kernel-upstream)  doins "${x}-a0-hr-b0-77.ucode" ;;
			*)
				ewarn "Unexpected kernel version '${kernel}'."
				ewarn "Installing all '${x}' files."
				doins "${x}"-*.ucode
				;;
			esac
			;;
		iwlwifi-so)
			case "${kernel}" in
			kernel-5_15)     doins "${x}-a0-gf-a0-89.ucode" ;;
			kernel-6_6)      doins "${x}-a0-gf-a0-89.ucode" ;;
			kernel-upstream) doins "${x}-a0-gf-a0-86.ucode" ;;
			*)               doins "${x}-a0-gf-a0-89.ucode" ;;
			esac
			doins "${x}-a0-gf-a0.pnvm"
			;;
		iwlwifi-so-a0-hr)
			case "${kernel}" in
			kernel-upstream) doins "${x}-b0-86.ucode" ;;
			*)               doins "${x}-b0-89.ucode" ;;
			esac
			;;
		iwlwifi-*) doins "${x}"-*.ucode ;;
		esac
	done
}

src_install() {
	local x
	insinto "${FIRMWARE_INSTALL_ROOT}"
	use_fw adreno-630 && doins_subdir qcom/a630*
	use_fw adreno-660 && doins_subdir qcom/a660*
	use_fw adsp_apl && doins_subdir intel/dsp_fw_bxtn_v2219.bin
	use_fw adsp_cnl && doins_subdir intel/dsp_fw_cnl*
	use_fw adsp_glk && doins_subdir intel/dsp_fw_glk*
	use_fw adsp_kbl && doins_subdir intel/dsp_fw_kbl*
	use_fw adsp_skl && doins_subdir intel/dsp_fw_*
	use_fw amd_ucode && doins_subdir amd-ucode/*.bin
	use_fw ath9k_htc && doins htc_*.fw
	use_fw ath10k_qca6174a-5 && doins_subdir ath10k/QCA6174/hw3.0/{firmware-6,board-2}.bin
	use_fw ath10k_qca6174a-3 && doins_subdir ath10k/QCA6174/hw3.0/{firmware-sdio-6,board-2}.bin
	use_fw ath10k_wcn3990 && doins_subdir ath10k/WCN3990/hw1.0/*
	use_fw ath11k_wcn6750 && doins_subdir ath11k/WCN6750/hw1.0/*
	use_fw ath11k_wcn6855 && doins_subdir ath11k/WCN6855/hw2.0/*
	use_fw ath11k_wcn6855 && dodir "${FIRMWARE_INSTALL_ROOT}"/ath11k/WCN6855/hw2.1
	use_fw bcm4354-bt && doins_subdir brcm/BCM4354_*.hcd
	use_fw cros-pd && doins_subdir cros-pd/*
	use_fw fw_sst && doins_subdir intel/fw_sst*
	use_fw fw_sst2 && doins_subdir intel/IntcSST2.bin
	use_fw i915_adl && doins_subdir i915/adl*
	use_fw i915_cnl && doins_subdir i915/cnl*
	use_fw i915_glk && doins_subdir i915/glk*
	use_fw i915_mtl && doins_subdir i915/mtl*
	use_fw i915_skl && doins_subdir i915/skl*
	use_fw i915_tgl && doins_subdir i915/tgl*
	use_fw ipu3_fw && doins_subdir intel/irci_*
	use_fw ipu6_fw && doins_subdir intel/ipu/ipu6*
	use_fw ibt_9260 && doins_subdir intel/ibt-18-16-1.*
	use_fw ibt_9462 && doins_subdir intel/ibt-{0040,1040}-1020.*
	use_fw ibt_9560 && doins_subdir intel/ibt-{17-{16-1,0-1,1},{0040,1040}-2120}.*
	use_fw ibt_ax200 && doins_subdir intel/ibt-20-*.*
	use_fw ibt_ax201 && doins_subdir intel/ibt-19-*.*
	use_fw ibt_ax203 && doins_subdir intel/ibt-{0040,1040}-4150.*
	use_fw ibt_ax210 && doins_subdir intel/ibt-0041-0041.*
	use_fw ibt_ax211 && doins_subdir intel/ibt-{0040,1040}-0041.*
	use_fw ibt_ax211_mtl && doins_subdir intel/ibt-0180-0041.*
	use_fw ibt_be200 && doins_subdir intel/ibt-0291-0291.*
	use_fw ibt-hw && doins_subdir intel/ibt-hw-*.bseq
	use_fw ibt-sec&& doins_subdir intel/ibt-0041-0041.* && doins_subdir intel/ibt-11-5.*
	use_fw ice && doins_subdir intel/ice/ddp/*
	use_fw keyspan_usb && doins_subdir keyspan/*
	use_fw marvell-mwlwifi && doins_subdir mwlwifi/*.bin
	use_fw marvell-pcie8897 && doins_subdir mrvl/pcie8897_uapsta.bin
	use_fw marvell-pcie8997 && doins_subdir mrvl/pcieusb8997_combo_v4.bin
	use_fw mt7920 && doins_subdir mediatek/WIFI_{MT7961_patch_mcu_1a_2_hdr,RAM_CODE_MT7961_1a}.bin
	use_fw mt7920-bt && doins_subdir mediatek/BT_RAM_CODE_MT7961_1a_2_hdr.bin
	use_fw mt7921e && doins_subdir mediatek/WIFI_{MT7961_patch_mcu_1_2_hdr,RAM_CODE_MT7961_1}.bin
	use_fw mt7921e-bt && doins_subdir mediatek/BT_RAM_CODE_MT7961_1_2_hdr.bin
	use_fw mt7922 && doins_subdir mediatek/WIFI_{MT7922_patch_mcu_1_1_hdr,RAM_CODE_MT7922_1}.bin
	use_fw mt7922-bt && doins_subdir mediatek/BT_RAM_CODE_MT7922_1_1_hdr.bin
	use_fw mt7925 && doins_subdir mediatek/mt7925/WIFI_{MT7925_PATCH_MCU_1_1_hdr,RAM_CODE_MT7925_1_1}.bin
	use_fw mt7925-bt && doins_subdir mediatek/mt7925/BT_RAM_CODE_MT7925_1_1_hdr.bin
	use_fw mt8173-vpu && doins_subdir mediatek/mt8173/vpu_{d,p}.bin
	use_fw nvidia-xusb && doins_subdir nvidia/tegra*/xusb.bin
	use_fw nxp_uwb_sr150 && doins_subdir nxp/sr150_fw.bin
	use_fw qca6174a-3-bt && doins_subdir qca/{nvm,rampatch}_0044*.bin
	use_fw qca6174a-5-bt && doins_subdir qca/{nvm,rampatch}_usb_00000302*.bin
	use_fw qca-wcn3990-bt && doins_subdir qca/{crbtfw21.tlv,crnv21.bin}
	use_fw qca-wcn3991-bt && doins_subdir qca/{crbtfw32.tlv,crnv32.bin,crnv32u.bin}
	use_fw qca-wcn685x-bt && doins_subdir qca/{nvm,rampatch}_usb_0013*.bin
	use_fw qca-wcn6750-bt && doins_subdir qca/{msnv11.bin,msbtfw11.*}
	use_fw rockchip-dptx && doins_subdir rockchip/dptx.bin
	use_fw rtl8107e-1 && doins_subdir rtl_nic/rtl8107e-1.fw
	use_fw rtl8107e-2 && doins_subdir rtl_nic/rtl8107e-2.fw
	use_fw rtl8125a-3 && doins_subdir rtl_nic/rtl8125a-3.fw
	use_fw rtl8125b-1 && doins_subdir rtl_nic/rtl8125b-1.fw
	use_fw rtl8125b-2 && doins_subdir rtl_nic/rtl8125b-2.fw
	use_fw rtl8153 && doins_subdir rtl_nic/rtl815[36]*.fw
	use_fw rtl8168fp-3 && doins_subdir rtl_nic/rtl8168fp-3.fw
	use_fw rtl8168g-1 && doins_subdir rtl_nic/rtl8168g-1.fw
	use_fw rtl8168g-2 && doins_subdir rtl_nic/rtl8168g-2.fw
	use_fw rtl8168h-1 && doins_subdir rtl_nic/rtl8168h-1.fw
	use_fw rtl8168h-2 && doins_subdir rtl_nic/rtl8168h-2.fw
	use_fw rtl_bt-8822ce-uart && doins_subdir rtl_bt/rtl8822cs*.bin
	use_fw rtl_bt-8822ce-usb && doins_subdir rtl_bt/rtl8822cu*.bin
	use_fw rtl_bt-8852ae-usb && doins_subdir rtl_bt/rtl8852au*.bin
	use_fw rtl_bt-8852be-usb && doins_subdir rtl_bt/rtl8852bu*.bin
	use_fw rtl_bt-8852be-vt-usb && doins_subdir rtl_bt/rtl8852btu*.bin
	use_fw rtl_bt-8852ce-usb && doins_subdir rtl_bt/rtl8852cu*.bin
	use_fw rtw8821c && ( insinto "${FIRMWARE_INSTALL_ROOT}/rtw88"; doins "${FILESDIR}/rtw8821c_fw.bin"; )
	use_fw rtw8822b && doins_subdir rtw88/rtw8822b*.bin
	use_fw rtw8822c && doins_subdir rtw88/rtw8822c*.bin
	use_fw rtw8852a && doins_subdir rtw89/rtw8852a*.bin
	use_fw rtw8852b && doins_subdir rtw89/rtw8852b*.bin
	use_fw rtw8852c && doins_subdir rtw89/rtw8852c*.bin
	use_fw venus-52 && doins_subdir qcom/venus-5.2/*
	use_fw venus-54 && doins_subdir qcom/venus-5.4/*
	use_fw venus-vpu-2 && doins_subdir qcom/vpu-2.0/*
	use video_cards_radeon && doins_subdir radeon/*

	if use_fw amdgpu_gc_11_0_1; then
		doins_subdir amdgpu/dcn_3_1_4*
		doins_subdir amdgpu/gc_11_0_1_*
		doins_subdir amdgpu/psp_13_0_4_*
		doins_subdir amdgpu/sdma_6_0_1*
		doins_subdir amdgpu/vcn_4_0_2.bin
	fi

	if use_fw amdgpu_gc_11_0_4; then
		doins_subdir amdgpu/dcn_3_1_4*
		doins_subdir amdgpu/gc_11_0_4_*
		doins_subdir amdgpu/psp_13_0_11_*
		doins_subdir amdgpu/sdma_6_0_1*
		doins_subdir amdgpu/vcn_4_0_2.bin
	fi

	if use_fw amdgpu_yellow_carp; then
		doins_subdir amdgpu/yellow_carp*
	fi

	use_fw rt2870 && doins rt2870.bin

	# The firmware here is a mess; install specific files by hand.
	if use linux_firmware_ath3k-all || use linux_firmware_ath3k-ar3011; then
		doins ath3k-1.fw
	fi
	if use linux_firmware_ath3k-all || use linux_firmware_ath3k-ar3012; then
		(
		insinto "${FIRMWARE_INSTALL_ROOT}/ar3k"
		doins ar3k/*.dfu
		)
	fi

	install_iwlwifi

	for x in "${IUSE_BRCMWIFI[@]}"; do
		use_fw "${x}" || continue
		case ${x} in
		brcmfmac-all)      doins_subdir brcm/brcmfmac* ;;
		brcmfmac4354-sdio) doins_subdir brcm/brcmfmac4354-sdio.* ;;
		brcmfmac4356-pcie) doins_subdir brcm/brcmfmac4356-pcie.* ;;
		brcmfmac4371-pcie) doins_subdir brcm/brcmfmac4371-pcie.* ;;
		esac
	done

	# Hanle 'Link:' directives in WHENCE. The Makefile's copy-firmware.sh
	# does this too, but we trim down the install list a lot, so we don't
	# use that script.
	local link target
	while read -r link target; do
		# ${target} is link-relative, so we need to construct a full path.
		local install_target="${D}/${FIRMWARE_INSTALL_ROOT}/$(dirname "${link}")/${target}"
		# Skip 'Link' directives for files we didn't install already.
		[[ -f "${install_target}" ]] || continue
		einfo "Creating link ${link} (${target})"
		dodir "${FIRMWARE_INSTALL_ROOT}/$(dirname "${link}")"
		dosym "${target}" "${FIRMWARE_INSTALL_ROOT}/${link}"
	done < <(grep -E '^Link:' WHENCE | sed -e's/^Link: *//g' -e's/-> //g')
}

src_test() {
	emake check
}
