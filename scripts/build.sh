#!/bin/bash
# Собирает Quick.app из Swift-пакета. Xcode открывать не нужно.
#
#   ./scripts/build.sh              — только сборка в ./build/Quick.app
#   ./scripts/build.sh --run        — сборка и запуск из ./build
#   ./scripts/build.sh --install    — сборка, установка в /Applications и запуск
#
# Подпись. Локальная сборка ищет в связке ключей постоянную личность и
# подписывает ею. Это не про безопасность, а про разрешения: ad-hoc подпись
# даёт каждой сборке свой хеш, macOS считает её новым приложением и сбрасывает
# доступ к Рабочему столу и «Универсальному доступу» — то есть после каждой
# пересборки шторка остаётся без скриншотов, а заготовки без автовставки.
# Постоянный сертификат делает requirement стабильным, и разрешения живут.
#
# Личность можно задать явно:
#
#   QUICK_SIGN_IDENTITY="Apple Development: Имя (TEAMID)" ./scripts/build.sh
#
# Нет ни одной — сборка подпишется ad-hoc и скажет об этом. На раздачу это
# никак не влияет: DMG собирает scripts/release.sh со своей подписью.
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

SIGN_IDENTITY="${QUICK_SIGN_IDENTITY-}"
# QUICK_ADHOC=1 отключает поиск личности. Так зовёт нас release.sh: раздаче
# личность для разработки не подходит совсем, там нужен Developer ID, и
# подписывает релиз он сам.
if [ -z "$SIGN_IDENTITY" ] && [ "${QUICK_ADHOC:-0}" != "1" ]; then
  # Developer ID предпочтительнее: он не протухает через год, как Development.
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi
if [ -z "$SIGN_IDENTITY" ] && [ "${QUICK_ADHOC:-0}" != "1" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ {print $2; exit}')"
fi

if [ -n "$SIGN_IDENTITY" ]; then
  echo "==> Подпись ($SIGN_IDENTITY)"
  codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP" >/dev/null
elif [ "${QUICK_ADHOC:-0}" = "1" ]; then
  echo "==> Подпись (ad-hoc, как и просили)"
  codesign --force --sign - --timestamp=none "$APP" >/dev/null
else
  echo "==> Подпись (ad-hoc) — постоянной личности в связке ключей нет"
  echo "    Разрешения macOS слетят после этой сборки: их придется выдать заново."
  codesign --force --sign - --timestamp=none "$APP" >/dev/null
fi

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
