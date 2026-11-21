#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MEOW="${MEOW:-$HOME/meow/target/release/meow}"
export MEOW_TC="${MEOW_TC:-$HOME/ios6-tooling/theos/toolchain/linux/iphone/bin}"
export MEOW_SDK_ARMV7="${MEOW_SDK_ARMV7:-$HOME/ios6-tooling/sdks/iPhoneOS6.1.sdk}"

cd "$ROOT"
"$MEOW" doctor
"$MEOW" build icons-smart launch-smart \
	image-vehicle-bus image-vehicle-trolley image-vehicle-tram image-vehicle-minibus \
	image-navposition image-location-button image-route-close image-zoom-plus image-zoom-minus \
	image-tab-map image-tab-routes image-tab-favorites image-tab-settings
"$MEOW" build SmartTransport-ipa "$@"
