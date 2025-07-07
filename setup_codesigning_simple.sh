#!/bin/bash

echo "🔐 Simple Code Signing Setup for DoomHUD"
echo ""

# Check if we already have a certificate
existing=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")
if [ ! -z "$existing" ]; then
    echo "✅ DoomHUD Developer certificate already exists:"
    echo "$existing"
    echo ""
    echo "You're all set! Use ./build_app_signed.sh to build."
    exit 0
fi

echo "We need to create a self-signed certificate for stable code signing."
echo ""
echo "This will open Keychain Access where you can create the certificate manually."
echo "It's much more reliable than trying to script it."
echo ""
echo "Steps you'll need to follow:"
echo "1. Keychain Access will open"
echo "2. Go to: Keychain Access > Certificate Assistant > Create a Certificate..."
echo "3. Fill in these details:"
echo "   - Name: DoomHUD Developer"
echo "   - Identity Type: Self Signed Root"
echo "   - Certificate Type: Code Signing"
echo "   - Let me override defaults: ✓ (check this)"
echo "4. Click Continue through the dialogs (defaults are fine)"
echo "5. Click Create"
echo "6. Close Keychain Access"
echo ""
echo "Ready to open Keychain Access? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Cancelled. Run this script again when ready."
    exit 1
fi

# Open Keychain Access
echo "🔓 Opening Keychain Access..."
open "/Applications/Utilities/Keychain Access.app"

echo ""
echo "⏳ Waiting for you to create the certificate..."
echo "Press Enter when you've created the 'DoomHUD Developer' certificate"
read -r

# Check if the certificate was created
echo "🔍 Checking for certificate..."
cert_check=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")

if [ ! -z "$cert_check" ]; then
    echo "✅ Perfect! Certificate found:"
    echo "$cert_check"
    echo ""
    echo "🎉 Setup complete! You can now use:"
    echo "   ./build_app_signed.sh"
    echo ""
    echo "This will give you stable permissions that persist even when you move the app!"
else
    echo "❌ Certificate not found. Possible issues:"
    echo "1. Certificate name must be exactly 'DoomHUD Developer'"
    echo "2. Certificate type must be 'Code Signing'"
    echo "3. Make sure it's in your login keychain"
    echo ""
    echo "Try running this script again, or use the fallback method:"
    echo "   ./build_app.sh  (uses ad-hoc signing)"
fi

echo ""
echo "Done! 🚀"