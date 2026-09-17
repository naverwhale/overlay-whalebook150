#!/bin/sh
#
# Copyright 2017 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Use the rust wrapper version as the version of the whole project.

# Assumes the first 'version =' line in the Cargo.toml is the version for the
# crate.
awk '/^version = / { print $3 }' "$1/installer/Cargo.toml" | head -n1 | tr -d '"'
