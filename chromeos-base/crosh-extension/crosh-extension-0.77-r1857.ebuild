# Copyright 2016 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="eaa745230ed411fc83792eb63486cebeca93309f"
CROS_WORKON_TREE=("3b031dffa5e3274215f3b524f9161aa8b74534bd" "ea74a53e6904b3cf6f2c452ad292faacd90bb971" "7dbd6a26a3c06ac8f455ea3adad31e171b08d1c1" "d3af3b58977f8639b6af18ff9a0aa563fcad7a2e" "1291fe966edca2b628146ea62c6b46e235de8681" "3853ab0df63a7f7e0a88538bffa75a5496d5036e" "297b94c825bfcc58feca6ce9bed4eb9b8ebb6a5e")
CROS_WORKON_PROJECT="apps/libapps"
CROS_WORKON_LOCALNAME="third_party/libapps"
CROS_WORKON_SUBTREE="libdot hterm nassh ssh_client terminal wasi-js-bindings wassh"

# Uprevs are managed by pupr.
CROS_WORKON_MANUAL_UPREV=1

inherit cros-workon

DESCRIPTION="The ChromiumOS Shell extension (the HTML/JS rendering part)"
HOMEPAGE="https://chromium.googlesource.com/apps/libapps/+/HEAD/nassh/docs/chromeos-crosh.md"
SRC_URI=""
# The pupr job keeps this value up-to-date.
PUPR_SRC_URI="
	https://storage.googleapis.com/chromeos-localmirror/secureshell/distfiles/fonts-d6dc5eaf459abd058cd3aef1e25963fde893f9d87f5f55f340431697ce4b3506.tar.xz
	https://storage.googleapis.com/chromeos-localmirror/secureshell/distfiles/node_modules-68c9bac624f418597fb6e2ea1819d3e44b23d013bad33f8d72090940f0727a30.tar.xz
	https://storage.googleapis.com/chromeos-localmirror/secureshell/releases/0.77.tar.xz
	https://storage.googleapis.com/chromium-nodejs/744e6926ffdd4a4fb2080ae2b9ce4575490261e7
"
SRC_URI+=" ${PUPR_SRC_URI}"

# The archives above live on Google maintained sites.
RESTRICT="mirror"

LICENSE="BSD-Google"
SLOT="0/0"
KEYWORDS="*"
IUSE=""

BDEPEND="
	sys-devel/gcc
"

PATCHES=(
        "${FILESDIR}/0001-WhaleOS-TerminalApp-Apply-whale-style-color.patch"
)

e() {
	echo "$@"
	"$@" || die
}

src_prepare() {
	default

	# TODO(vapier): Rework this integration.
	# NB: The inserts have to be a sep command from the replacements.
	sed -i \
		-e '1iconst gitDate = pkg.gitDate;' \
		-e '1iconst version = pkg.version;' \
		-e '1iconst gitCommitHash = pkg.gitCommitHash;' \
		{libdot,hterm,nassh}/js/deps_resources.shim.js || die
	sed -i \
		-e '/^import .*package.json/d' \
		-e "s|pkg.version|'${PV}'|" \
		-e "s|pkg.gitDate|'$(date)'|" \
		-e "s|pkg.gitCommitHash|'${CROS_WORKON_COMMIT:-9999}'|" \
		{libdot,hterm,nassh}/js/deps_resources.shim.js || die
}

src_compile() {
	e ./nassh/bin/mkdist --crosh-only --skip-zip
}

src_install() {
	local dir="/usr/share/chromeos-assets/crosh_builtin"
	insinto "${dir}"
	doins -r nassh/dist/tmp/crosh/*
}
