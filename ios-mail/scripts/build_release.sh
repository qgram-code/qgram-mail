#!/usr/bin/env bash
# Сборка релиза QGram Mail: архив + экспорт IPA.
# Запускается на macOS с Xcode 15+ (на Linux xcodebuild не существует).
#
#   TEAM_ID=ABCDE12345 scripts/build_release.sh              # ad-hoc IPA
#   TEAM_ID=ABCDE12345 METHOD=app-store scripts/build_release.sh
#
# Результат: build/QGramMail.xcarchive и build/export/QGramMail.ipa
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/QGramMail.xcodeproj"
SCHEME="QGramMail"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/QGramMail.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
METHOD="${METHOD:-ad-hoc}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild не найден — релиз собирается только на macOS с Xcode." >&2
  exit 1
fi

if [ -z "${TEAM_ID:-}" ]; then
  echo "Укажите TEAM_ID (Apple Developer Team ID), например: TEAM_ID=ABCDE12345 $0" >&2
  exit 1
fi

echo "==> Проект пересобирается из исходников"
python3 "$ROOT/scripts/generate_appicon.py"
python3 "$ROOT/scripts/generate_xcodeproj.py"

rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR"

EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>${METHOD}</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST

echo "==> Архив (Release)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic

echo "==> Экспорт IPA (${METHOD})"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST"

echo
echo "Готово:"
echo "  архив: $ARCHIVE"
find "$EXPORT_DIR" -name '*.ipa' -exec echo "  IPA:   {}" \;
