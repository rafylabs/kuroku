#!/usr/bin/env bash
set -e

# Kotatsu iOS Sideload Package Builder
# Builds unsigned IPA for AltStore, SideStore, TrollStore, and Sideloadly

echo "⚡ [Kotatsu iOS] Building release bundle for iOS (No Code Sign)..."
flutter build ios --no-codesign --release

OUTPUT_DIR="build/ios/ipa"
PAYLOAD_DIR="$OUTPUT_DIR/Payload"

echo "📦 [Kotatsu iOS] Packaging into IPA payload structure..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$PAYLOAD_DIR"

# Copy compiled Runner.app into Payload
cp -r "build/ios/iphoneos/Runner.app" "$PAYLOAD_DIR/Kotatsu.app"

# Create IPA archive
cd "$OUTPUT_DIR"
zip -r -q "Kotatsu.ipa" "Payload"
rm -rf "Payload"
cd - > /dev/null

echo "✓ [Kotatsu iOS] Successfully created sideloadable IPA at:"
echo "  → $(pwd)/$OUTPUT_DIR/Kotatsu.ipa"
echo ""
echo "How to install on iOS without App Store:"
echo "  1. AltStore / SideStore: Share Kotatsu.ipa to AltStore / SideStore app on your device."
echo "  2. TrollStore (iOS 14 - 17.0): Open Kotatsu.ipa directly in TrollStore."
echo "  3. Sideloadly: Drag Kotatsu.ipa into Sideloadly on Mac/PC and install via USB/Wi-Fi."
