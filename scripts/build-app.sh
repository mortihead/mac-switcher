#!/bin/bash
# Собирает build/MacSwitcher.app из Swift-пакета.
#
#   ./scripts/build-app.sh            # release-сборка
#   ./scripts/build-app.sh debug      # debug-сборка
#
# Подпись: если в связке ключей есть сертификат подписи кода "MacSwitcher Dev" (можно самоподписанный),
# сборка подписывается им, иначе ad-hoc ("-"). С постоянным сертификатом macOS не сбрасывает
# разрешение «Универсальный доступ» после каждой пересборки. Сертификат можно задать и явно:
#   SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" ./scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
DEFAULT_IDENTITY="MacSwitcher Dev"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    # Без -v: самоподписанный сертификат система считает недоверенным, но подписывать им можно.
    if security find-identity -p codesigning | grep -q "\"$DEFAULT_IDENTITY\""; then
        SIGN_IDENTITY="$DEFAULT_IDENTITY"
    else
        SIGN_IDENTITY="-"
    fi
fi
APP="build/MacSwitcher.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacSwitcher" "$APP/Contents/MacOS/MacSwitcher"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Готово: $APP (подпись: $SIGN_IDENTITY)"
echo "Запуск: open $APP"
