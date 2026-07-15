#!/usr/bin/env bash
#
# Собирает libbox.aar (ядро sing-box) для Android из официальных исходников
# и кладёт в android/app/libs/. Бинарник намеренно не хранится в git (88 МБ) —
# его нужно собрать этим скриптом перед сборкой приложения.
#
# Требования: Android SDK + NDK, интернет. Go и gomobile-форк ставятся скриптом.
# Пин версии ядра: sing-box v1.13.14 (go.mod требует Go 1.25.0).
#
# Использование:
#   ANDROID_HOME=~/Library/Android/sdk \
#   ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/<version> \
#   scripts/build_libbox.sh
#
set -euo pipefail

SINGBOX_VERSION="v1.13.14"
GO_VERSION="go1.25.0"
GOMOBILE_VERSION="v0.1.12"

: "${ANDROID_HOME:?set ANDROID_HOME to your Android SDK path}"
: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to an installed NDK path}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
export PATH="$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin:$PATH"

echo "==> Go $GO_VERSION toolchain (sing-box $SINGBOX_VERSION requires it)"
go install "golang.org/dl/${GO_VERSION}@latest"
"$HOME/go/bin/${GO_VERSION}" download
export PATH="$HOME/sdk/${GO_VERSION}/bin:$PATH"
export GOTOOLCHAIN=local
go version

echo "==> clone sing-box $SINGBOX_VERSION"
git clone --depth 1 --branch "$SINGBOX_VERSION" https://github.com/SagerNet/sing-box.git "$WORK/sing-box"
cd "$WORK/sing-box"

echo "==> sagernet gomobile fork $GOMOBILE_VERSION"
go install -v "github.com/sagernet/gomobile/cmd/gomobile@${GOMOBILE_VERSION}"
go install -v "github.com/sagernet/gomobile/cmd/gobind@${GOMOBILE_VERSION}"

echo "==> resolve go.sum (with_tailscale pulls extra deps)"
export GOFLAGS=-mod=mod
go mod download
go mod tidy

echo "==> build libbox (JDK 17 required)"
go run ./cmd/internal/build_libbox -target android

mkdir -p "$REPO_ROOT/android/app/libs"
cp "$WORK/sing-box/libbox.aar" "$REPO_ROOT/android/app/libs/libbox.aar"
echo "==> done: android/app/libs/libbox.aar"
