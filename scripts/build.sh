#!/bin/bash
# Собирает Quick.app из Swift-пакета. Xcode открывать не нужно.
#
#   ./scripts/build.sh              — только сборка в ./build/Quick.app
#   ./scripts/build.sh --run        — сборка и запуск из ./build
#   ./scripts/build.sh --install    — сборка, установка в /Applications и запуск
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Quick"
BUNDLE_ID="com.fedorwork.quick"
APP="$ROOT/build/$APP_NAME.app"

RUN=0
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --run) RUN=1 ;;
    --install) INSTALL=1; RUN=1 ;;
    *) echo "Неизвестный аргумент: $arg" >&2; exit 1 ;;
  esac
done

echo "==> Сборка (release, arm64)"
swift build -c release --package-path "$ROOT"
BINARY="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$APP_NAME"

echo "==> Сборка бандла"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Подпись (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP" >/dev/null

# Старый экземпляр держит окно на челке — снимаем до подмены бандла.
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.3

if [ "$INSTALL" -eq 1 ]; then
  echo "==> Установка в /Applications"
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
  TARGET="/Applications/$APP_NAME.app"
else
  TARGET="$APP"
fi

if [ "$RUN" -eq 1 ]; then
  echo "==> Запуск $TARGET"
  open "$TARGET"
else
  echo "==> Готово: $APP"
fi
