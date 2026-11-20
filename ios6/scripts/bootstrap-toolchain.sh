#!/bin/sh
set -eu

ROOT="${IOS6_TOOLING:-$HOME/ios6-tooling}"
THEOS="$ROOT/theos"
SDKS_REPO="$ROOT/iOS-sdks"
SDK="$ROOT/sdks/iPhoneOS6.1.sdk"
ARCHIVE="$ROOT/iOSToolchain-x86_64.tar.xz"
TOOLCHAIN_URL="https://github.com/L1ghtmann/llvm-project/releases/download/test-210562a/iOSToolchain-x86_64.tar.xz"
TOOLCHAIN_SHA256="a72a7a577e2fbe2838b6b5e9c72034fa7d114af96f0e1d4b016f18730ce4056e"

mkdir -p "$ROOT"

if [ ! -d "$THEOS/.git" ]; then
	git clone --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

if [ ! -d "$SDKS_REPO/.git" ]; then
	git clone --depth 1 --filter=blob:none --sparse https://github.com/qianjigui/iOS-sdks.git "$SDKS_REPO"
fi
git -C "$SDKS_REPO" sparse-checkout set iPhoneOS6.1.sdk

if [ ! -x "$THEOS/toolchain/linux/iphone/bin/clang" ]; then
	curl -fL --retry 3 -o "$ARCHIVE" "$TOOLCHAIN_URL"
	printf '%s  %s\n' "$TOOLCHAIN_SHA256" "$ARCHIVE" | sha256sum -c -
	mkdir -p "$THEOS/toolchain"
	tar -xJf "$ARCHIVE" -C "$THEOS/toolchain"
fi

if [ ! -f "$SDK/usr/include/stdio.h" ]; then
	mkdir -p "$ROOT/sdks"
	cat "$SDKS_REPO/iPhoneOS6.1.sdk/iPhoneOS6.1.sdk.zip.001" \
		"$SDKS_REPO/iPhoneOS6.1.sdk/iPhoneOS6.1.sdk.zip.002" \
		"$SDKS_REPO/iPhoneOS6.1.sdk/iPhoneOS6.1.sdk.zip.003" > "$ROOT/iPhoneOS6.1.sdk.zip"
	unzip -q -o "$ROOT/iPhoneOS6.1.sdk.zip" -d "$ROOT/sdks"
fi

printf 'Toolchain: %s\nSDK: %s\n' "$THEOS/toolchain/linux/iphone/bin" "$SDK"
