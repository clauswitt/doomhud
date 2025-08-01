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
    <key>NSInputMonitoringUsageDescription</key>
    <string>DoomHUD needs input monitoring access to track mouse clicks and keystrokes for productivity analysis.</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>DoomHUD needs to monitor system events for productivity tracking.</string>
</dict>
</plist>
EOF

# Create entitlements file for Input Monitoring
cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

# Sign the app bundle with explicit identifier and timestamp
echo "🔒 Code signing the app with explicit bundle identifier..."
codesign --force --deep --sign - --identifier com.clauswitt.doomhud --timestamp --entitlements entitlements.plist DoomHUD.app

# Verify the signature
echo "🔍 Verifying signature..."
codesign --verify --deep --strict DoomHUD.app
if [ $? -eq 0 ]; then
    echo "✅ Signature verification successful"
else
    echo "❌ Signature verification failed"
fi

# Clean up
rm entitlements.plist

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