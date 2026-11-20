#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MEOW="${MEOW:-$HOME/meow/target/release/meow}"
export MEOW_TC="${MEOW_TC:-$HOME/ios6-tooling/theos/toolchain/linux/iphone/bin}"
export MEOW_SDK_ARMV7="${MEOW_SDK_ARMV7:-$HOME/ios6-tooling/sdks/iPhoneOS6.1.sdk}"

cd "$ROOT"
"$MEOW" doctor
"$MEOW" build icons-smart launch-smart
"$MEOW" build SmartTransport-ipa "$@"
