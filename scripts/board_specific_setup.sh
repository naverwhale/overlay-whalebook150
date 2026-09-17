# Board hooks for build_image (sourced by chromite/shell/build_image.sh; the
# functions below run with root_fs_dir / stateful_fs_dir / BOARD_ROOT set).
SCRIPT_ROOT="$(dirname "$(readlink -f "$0")")"
WHALEOS_SRC_ROOT="${SCRIPT_ROOT}/../../src"
OVERLAY_DIR="${WHALEOS_SRC_ROOT}/overlays/overlay-whalebook"

board_finalize_base_image() {
  if [[ "${UPDATE_CHROME_DEV_CONF:-0}" == "1" ]]; then
    sudo cp "${OVERLAY_DIR}/files/chrome_dev.conf" "${root_fs_dir}/etc/chrome_dev.conf"
    info "Successfully updated chrome_dev.conf"
  fi

  if [[ -f "${OVERLAY_DIR}/files/bootx64.efi" ]]; then
    sudo cp "${OVERLAY_DIR}/files/bootx64.efi" "${root_fs_dir}/boot/efi/boot/bootx64.efi"
  fi
  if [[ -f "${OVERLAY_DIR}/files/grubx64.efi" ]]; then
    sudo cp "${OVERLAY_DIR}/files/grubx64.efi" "${root_fs_dir}/boot/efi/boot/grubx64.efi"
  fi

  # Pre-install the Waydroid Android images (app-containers/waydroid-images) into
  # the stateful partition so waydroid finds them at
  # /usr/local/share/waydroid-extra/images and does not download ~840 MB into the
  # small encrypted stateful on first boot (which fills it up and breaks sign-in).
  local waydroid_img_src="${BOARD_ROOT}/build/share/waydroid-extra/images"
  local waydroid_img_dst="${stateful_fs_dir}/dev_image/share/waydroid-extra/images"
  # Expand the glob first: with no *.img the pattern would be passed to cp
  # verbatim and the hook would die with an unhelpful message.
  local waydroid_imgs=( "${waydroid_img_src}"/*.img )
  if [[ -e "${waydroid_imgs[0]}" ]]; then
    info "Installing ${#waydroid_imgs[@]} Waydroid Android image(s) to the stateful partition"
    sudo mkdir -p "${waydroid_img_dst}"
    sudo cp "${waydroid_imgs[@]}" "${waydroid_img_dst}/"
  else
    info "No Waydroid images (*.img) under ${waydroid_img_src}, skipping"
  fi
}
