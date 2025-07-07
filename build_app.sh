#!/bin/bash

# Build script to create proper macOS app bundle

echo "🎮 Building DoomHUD.app..."

# Clean previous builds
rm -rf DoomHUD.app .build/release

# Build the executable
echo "📦 Compiling..."
swift build -c release

# Create app bundle structure
mkdir -p DoomHUD.app/Contents/MacOS
mkdir -p DoomHUD.app/Contents/Resources

# Copy executable
cp .build/release/DoomHUD DoomHUD.app/Contents/MacOS/

# Create Info.plist
cat > DoomHUD.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DoomHUD</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.clauswitt.doomhud</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DoomHUD</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSCameraUsageDescription</key>
    <string>DoomHUD needs camera access to display webcam feed and detect motion for productivity tracking.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>DoomHUD needs Apple Events access to monitor system activity for productivity tracking.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>DoomHUD needs system administration access to monitor keyboard and mouse activity for productivity tracking.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>DoomHUD needs screen recording access to capture screenshots for timelapse generation.</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ DoomHUD.app created successfully!"
echo ""
echo "🚀 To run the app:"
echo "   open DoomHUD.app"
echo ""
echo "🔒 For permissions:"
echo "   The app will appear as 'DoomHUD' in System Preferences > Security & Privacy"
echo "   You need to grant: Accessibility, Input Monitoring, Camera, Screen Recording"
echo ""
echo "💀 Look for the skull emoji (💀) in your menu bar when running!"