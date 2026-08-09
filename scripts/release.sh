#!/bin/bash
# Собирает Quick.dmg для публикации на GitHub.
#
#   ./scripts/release.sh
#
# Подпись по умолчанию ad-hoc: скачанное приложение macOS пометит карантином,
# и первый запуск придётся делать через правый клик → «Открыть». Чтобы выпустить
# релиз без предупреждений, нужен платный Developer ID — тогда:
#
#   QUICK_SIGN_IDENTITY="Developer ID Application: Имя (TEAMID)" ./scripts/release.sh
#
# и следом нотаризация:
#
#   xcrun notarytool submit dist/Quick-<версия>.dmg --keychain-profile <профиль> --wait
#   xcrun stapler staple dist/Quick-<версия>.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Quick"
APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"
STAGING="$ROOT/build/dmg-staging"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

echo "==> Иконка"
swift "$ROOT/scripts/make-icon.swift" >/dev/null

echo "==> Сборка $APP_NAME $VERSION"
# Локальная сборка подписывается постоянной личностью из связки ключей, чтобы
# не слетали разрешения macOS. Раздаче она не годится: сертификат разработки
# чужим машинам ничего не даёт, а Team ID лишний раз светить незачем.
# Поэтому здесь — ad-hoc, а настоящую подпись ставим ниже.
QUICK_ADHOC=1 "$ROOT/scripts/build.sh" >/dev/null

if [ -n "${QUICK_SIGN_IDENTITY:-}" ]; then
  echo "==> Подпись Developer ID"
  # Hardened runtime обязателен для нотаризации.
  codesign --force --options runtime --timestamp \
    --sign "$QUICK_SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP"
else
  echo "==> Подпись ad-hoc (Developer ID не задан)"
fi

echo "==> Сборка образа"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING" "$DIST"
cp -R "$APP" "$STAGING/$APP_NAME.app"
# Симлинк рядом с приложением: перетащить в «Программы» прямо из окна образа.
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGING"

echo
echo "Готово: $DMG"
echo "Размер: $(du -h "$DMG" | cut -f1)"
if [ -z "${QUICK_SIGN_IDENTITY:-}" ]; then
  echo
  echo "Подпись ad-hoc — при первом запуске у пользователя сработает Gatekeeper."
  echo "Инструкция для README уже описана в разделе «Установка»."
fi
