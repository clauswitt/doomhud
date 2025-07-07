#!/bin/bash

# Build script with proper code signing for stable permissions

echo "🎮 Building DoomHUD.app with proper code signing..."

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

# Create entitlements file
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

# Check if we have the DoomHUD Developer certificate
CERT_NAME="DoomHUD Developer"

# First try to find it in the identity list
cert_check=$(security find-identity -v -p codesigning | grep "$CERT_NAME")

if [ ! -z "$cert_check" ]; then
    echo "✅ Found certificate in identity list: $CERT_NAME"
    SIGNING_IDENTITY="$CERT_NAME"
else
    # Try to find the certificate by hash (backup method)
    cert_hash=$(security find-certificate -c "$CERT_NAME" -Z ~/Library/Keychains/login.keychain-db 2>/dev/null | grep "SHA-1 hash:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    if [ ! -z "$cert_hash" ]; then
        echo "✅ Found certificate by hash: $cert_hash"
        echo "🔧 Certificate exists but may have access control issues"
        SIGNING_IDENTITY="$cert_hash"
    else
        echo ""
        echo "❌ No '$CERT_NAME' certificate found!"
        echo "Please run: ./setup_codesigning_simple.sh first"
        echo ""
        echo "Falling back to ad-hoc signing..."
        SIGNING_IDENTITY="-"
    fi
fi

# Sign the app bundle
echo "🔒 Code signing the app with identity: $SIGNING_IDENTITY"
codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --identifier com.clauswitt.doomhud \
    --entitlements entitlements.plist \
    DoomHUD.app

# Verify the signature
echo "🔍 Verifying signature..."
codesign --verify --deep --strict DoomHUD.app
if [ $? -eq 0 ]; then
    echo "✅ Signature verification successful"
    
    # Show signature details
    echo ""
    echo "📋 Signature details:"
    codesign -dv DoomHUD.app
else
    echo "❌ Signature verification failed"
fi

# Clean up
rm entitlements.plist

echo ""
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
echo ""

if [ "$SIGNING_IDENTITY" != "-" ]; then
    echo "🎯 This build uses proper code signing - permissions should persist!"
else
    echo "⚠️  This build uses ad-hoc signing - permissions may not persist"
    echo "   Run ./setup_codesigning.sh for stable permissions"
fi