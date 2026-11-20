#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MEOW_DIR="${MEOW_DIR:-$HOME/meow}"
MEOW_REPO="https://github.com/sqmrak/meow"
TOOLING_ROOT="${IOS6_TOOLING:-$HOME/ios6-tooling}"

if [ "$(uname -s)" != "Linux" ]; then
	printf '%s\n' "sry, but prepare.sh only supports linux" >&2
	exit 1
fi

case "$(uname -m)" in
	x86_64|amd64) ;;
	*)
		printf '%s\n' "The pinned iOS toolchain in this project is for x86_64 Linux." >&2
		exit 1
		;;
esac

if [ "$(id -u)" -eq 0 ]; then
	SUDO=""
elif command -v sudo >/dev/null 2>&1; then
	SUDO="sudo"
else
	printf '%s\n' "sudo is required to install system packages." >&2
	exit 1
fi

install_debian() {
	$SUDO apt-get update
	$SUDO apt-get install -y build-essential git curl ca-certificates xz-utils unzip tar coreutils pkg-config libxml2
	if ! $SUDO apt-get install -y libtinfo6; then
		$SUDO apt-get install -y libtinfo5
	fi
}

install_arch() {
	$SUDO pacman -Syu --needed --noconfirm base-devel git curl ca-certificates xz unzip tar coreutils pkgconf libxml2 ncurses
}

install_fedora() {
	$SUDO dnf install -y gcc gcc-c++ make git curl ca-certificates xz unzip tar coreutils pkgconf-pkg-config libxml2 ncurses-compat-libs
}

install_rhel_yum() {
	$SUDO yum install -y gcc gcc-c++ make git curl ca-certificates xz unzip tar coreutils pkgconfig libxml2 ncurses-libs
}

install_suse() {
	$SUDO zypper --non-interactive refresh
	$SUDO zypper --non-interactive install -t pattern devel_basis
	$SUDO zypper --non-interactive install git curl ca-certificates xz unzip tar coreutils pkg-config libxml2-2 libncurses6
}

install_alpine() {
	$SUDO apk update
	$SUDO apk add build-base git curl ca-certificates xz unzip tar coreutils pkgconf libxml2 gcompat ncurses-libs
}

install_void() {
	$SUDO xbps-install -Suy xbps
	$SUDO xbps-install -Sy base-devel git curl ca-certificates xz unzip tar coreutils pkg-config libxml2 ncurses-libs
}

if [ -r /etc/os-release ]; then
	# ID and ID_LIKE are provided by the distribution.
	. /etc/os-release
else
	ID="unknown"
	ID_LIKE=""
fi
ID=${ID:-unknown}
ID_LIKE=${ID_LIKE:-}

DISTRO=" $ID $ID_LIKE "
case "$DISTRO" in
	*debian*|*ubuntu*) install_debian ;;
	*arch*|*manjaro*|*endeavouros*) install_arch ;;
	*fedora*) install_fedora ;;
	*rhel*|*centos*|*rocky*|*almalinux*)
		if command -v dnf >/dev/null 2>&1; then install_fedora; else install_rhel_yum; fi
		;;
	*suse*|*opensuse*) install_suse ;;
	*alpine*) install_alpine ;;
	*void*) install_void ;;
	*)
		if command -v apt-get >/dev/null 2>&1; then install_debian
		elif command -v pacman >/dev/null 2>&1; then install_arch
		elif command -v dnf >/dev/null 2>&1; then install_fedora
		elif command -v yum >/dev/null 2>&1; then install_rhel_yum
		elif command -v zypper >/dev/null 2>&1; then install_suse
		elif command -v apk >/dev/null 2>&1; then install_alpine
		elif command -v xbps-install >/dev/null 2>&1; then install_void
		else
			printf 'Unsupported Linux distribution: %s\n' "$ID" >&2
			exit 1
		fi
		;;
esac

# Meow recommends an official Rust release. Keep an existing toolchain, or
# install the current stable one through rustup when Rust is absent.
NEED_RUSTUP=0
if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
	NEED_RUSTUP=1
else
	RUST_VERSION=$(rustc --version | awk '{print $2}')
	RUST_MAJOR=${RUST_VERSION%%.*}
	RUST_REST=${RUST_VERSION#*.}
	RUST_MINOR=${RUST_REST%%.*}
	if [ "$RUST_MAJOR" -lt 1 ] || { [ "$RUST_MAJOR" -eq 1 ] && [ "$RUST_MINOR" -lt 70 ]; }; then
		NEED_RUSTUP=1
	fi
fi

if [ "$NEED_RUSTUP" -eq 1 ]; then
	RUSTUP_INIT=$(mktemp)
	curl -fL --retry 3 https://sh.rustup.rs -o "$RUSTUP_INIT"
	sh "$RUSTUP_INIT" -y --profile minimal --default-toolchain stable
	rm -f "$RUSTUP_INIT"
fi

PATH="$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PATH

if [ -e "$MEOW_DIR" ] && [ ! -d "$MEOW_DIR/.git" ]; then
	printf '%s is not a Meow git checkout; move it or set MEOW_DIR.\n' "$MEOW_DIR" >&2
	exit 1
fi

if [ ! -d "$MEOW_DIR/.git" ]; then
	git clone "$MEOW_REPO" "$MEOW_DIR"
elif [ "${UPDATE_MEOW:-0}" = "1" ]; then
	git -C "$MEOW_DIR" pull --ff-only
else
	printf 'Using existing Meow checkout: %s\n' "$MEOW_DIR"
fi

cd "$MEOW_DIR"
cargo build --release
if [ "${SKIP_MEOW_TESTS:-0}" != "1" ]; then
	cargo test
fi
cd "$PROJECT_ROOT"

MEOW_BIN="$MEOW_DIR/target/release/meow"
if [ ! -x "$MEOW_BIN" ]; then
	printf 'Meow binary was not produced: %s\n' "$MEOW_BIN" >&2
	exit 1
fi

IOS6_TOOLING="$TOOLING_ROOT" "$PROJECT_ROOT/ios6/scripts/bootstrap-toolchain.sh"

export MEOW="$MEOW_BIN"
export MEOW_TC="${MEOW_TC:-$TOOLING_ROOT/theos/toolchain/linux/iphone/bin}"
export MEOW_SDK_ARMV7="${MEOW_SDK_ARMV7:-$TOOLING_ROOT/sdks/iPhoneOS6.1.sdk}"
cd "$PROJECT_ROOT"
"$MEOW_BIN" doctor

if [ "$MEOW_DIR" = "$HOME/meow" ] && [ "$TOOLING_ROOT" = "$HOME/ios6-tooling" ]; then
	printf '\nEnvironment is ready. Build with:\n  ./ios6/scripts/build.sh -j 8\n'
else
	printf '\nEnvironment is ready. Build with:\n  MEOW=%s MEOW_TC=%s MEOW_SDK_ARMV7=%s ./ios6/scripts/build.sh -j 8\n' \
		"$MEOW_BIN" "$MEOW_TC" "$MEOW_SDK_ARMV7"
fi
