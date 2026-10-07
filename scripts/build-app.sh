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
#
# Для релиза (так собирает GitHub Actions):
#   VERSION=1.2.0 BUILD_NUMBER=7 UNIVERSAL=1 ./scripts/build-app.sh
# VERSION и BUILD_NUMBER записываются в Info.plist (CFBundleShortVersionString и CFBundleVersion),
# UNIVERSAL=1 собирает один бинарник для Apple Silicon и Intel.
# Без VERSION версия берётся из последнего git-тега v* (v0.1.0 -> 0.1.0), без BUILD_NUMBER номер
# сборки равен числу коммитов. Apple требует в этих ключах только числа через точку, поэтому хэш
# коммита (с пометкой -dirty при незакоммиченных изменениях) пишется в отдельный ключ MSGitCommit.
# Если git недоступен, остаются значения из Resources/Info.plist.
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

if [[ -z "${VERSION:-}" ]]; then
    VERSION="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
    VERSION="${VERSION#v}"
fi
if [[ -z "${BUILD_NUMBER:-}" ]]; then
    BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || true)"
fi
GIT_COMMIT="$(git describe --always --dirty --abbrev=7 --exclude '*' 2>/dev/null || true)"

BUILD_ARGS=(-c "$CONFIG")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacSwitcher" "$APP/Contents/MacOS/MacSwitcher"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
fi
if [[ -n "$GIT_COMMIT" ]]; then
    /usr/libexec/PlistBuddy -c "Add :MSGitCommit string $GIT_COMMIT" "$APP/Contents/Info.plist"
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Готово: $APP (версия: ${VERSION:-из Info.plist}, сборка: ${BUILD_NUMBER:-из Info.plist}, подпись: $SIGN_IDENTITY)"
echo "Запуск: open $APP"
