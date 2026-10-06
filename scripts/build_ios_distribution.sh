#!/usr/bin/env bash
set -euo pipefail

# Baganetic iOS Distribution & IPA Packaging Script
# Run this script on macOS to generate a release build and installable .ipa

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "=========================================="
echo "  Baganetic iOS Release Build & Packaging "
echo "=========================================="

# Check for Flutter
if command -v fvm &> /dev/null; then
  FLUTTER_BIN="fvm flutter"
elif command -v flutter &> /dev/null; then
  FLUTTER_BIN="flutter"
else
  echo "Error: Flutter SDK not found in PATH."
  exit 1
fi

echo "Using Flutter: ${FLUTTER_BIN}"

# Optional Dart defines for AI / secrets
AI_BUILD_DEFINES=""
if [ -f "config/dart_defines.local.env" ]; then
  AI_BUILD_DEFINES="--dart-define-from-file=config/dart_defines.local.env"
  echo "Loaded local configuration: config/dart_defines.local.env"
fi

echo "1. Fetching dependencies..."
${FLUTTER_BIN} pub get

echo "2. Building release iOS application bundle..."
${FLUTTER_BIN} build ios --no-codesign --release ${AI_BUILD_DEFINES}

OUTPUT_DIR="${PROJECT_ROOT}/build/ios/iphoneos"
RUNNER_APP="${OUTPUT_DIR}/Runner.app"

if [ ! -d "${RUNNER_APP}" ]; then
  echo "Error: Runner.app not found at ${RUNNER_APP}"
  exit 1
fi

echo "3. Packaging installable iOS IPA..."
PAYLOAD_DIR="${OUTPUT_DIR}/Payload"
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
cp -R "${RUNNER_APP}" "${PAYLOAD_DIR}/"

IPA_NAME="Baganetic-v1.0.3.ipa"
cd "${OUTPUT_DIR}"
rm -f "${IPA_NAME}"
zip -r -9 "${IPA_NAME}" Payload > /dev/null
rm -rf Payload

echo "4. Creating developer Runner.app archive..."
tar -czf Runner.app.tar.gz Runner.app

echo ""
echo "=========================================="
echo "  iOS Build & Packaging Complete!"
echo "=========================================="
echo "Installable IPA:  ${OUTPUT_DIR}/${IPA_NAME}"
echo "Developer App:    ${OUTPUT_DIR}/Runner.app.tar.gz"
echo ""
echo "Installation options for iOS testers & users:"
echo "  • Sideloadly (Mac/PC): Drag & drop ${IPA_NAME} to install with any Apple ID."
echo "  • AltStore / SideStore: Open ${IPA_NAME} on your iPhone/iPad to install."
echo "  • TrollStore (iOS 14-17): Direct install without 7-day resigning."
echo "  • Xcode / Devices: Use Xcode's 'Devices and Simulators' window to install."
echo "=========================================="
