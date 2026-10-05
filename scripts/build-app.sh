#!/bin/bash
# Собирает build/MacSwitcher.app из Swift-пакета.
#
#   ./scripts/build-app.sh            # release-сборка
#   ./scripts/build-app.sh debug      # debug-сборка
#
# Подпись: по умолчанию ad-hoc ("-"). Чтобы macOS не сбрасывала разрешение «Универсальный доступ»
# после каждой пересборки, подпишите постоянным сертификатом:
#   SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" ./scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/MacSwitcher.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacSwitcher" "$APP/Contents/MacOS/MacSwitcher"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Готово: $APP"
echo "Запуск: open $APP"
