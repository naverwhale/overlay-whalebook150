#!/bin/sh
# Copyright 2023 The Whale OS Authors.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

DEVICE=$1
IIO_DEVICES="/sys/bus/iio/devices"

set_sysfs_entry() {
  local name="$1"
  local value="$2"

  echo "${value}" > "${name}"
}

main() {
  local name
  local path

  echo "init angl device"
  name="$(cat "${IIO_DEVICES}/${DEVICE}/name")"
  path="${IIO_DEVICES}/${DEVICE}"
  if [ "${name}" = "angl" ]; then
    set_sysfs_entry "${path}/sampling_frequency" 25
    set_sysfs_entry "${path}/scan_elements/in_angl0_en" 1
    set_sysfs_entry "${path}/scan_elements/in_timestamp_en" 1
    set_sysfs_entry "${path}/buffer/length" 1
    set_sysfs_entry "${path}/buffer/enable" 1
    echo "init angl device done"
  fi
}

main "$@"
