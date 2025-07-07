#!/bin/bash

echo "🔧 Fixing DoomHUD Developer Certificate"
echo ""

echo "I can see you have DoomHUD Developer certificates in Keychain Access, but they're not"
echo "being recognized as a code signing identity. This usually means the certificate"
echo "and private key aren't properly linked."
echo ""

echo "Let's try a few fixes:"
echo ""

# Try to set the key partition list for code signing
echo "1️⃣ Setting key partition list for code signing..."
security set-key-partition-list -S apple-tool:,apple: -k "" ~/Library/Keychains/login.keychain-db 2>/dev/null

# Check if that worked
cert_check=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")
if [ ! -z "$cert_check" ]; then
    echo "✅ Success! Certificate is now working:"
    echo "$cert_check"
    echo ""
    echo "You can now use: ./build_app_signed.sh"
    exit 0
fi

echo "2️⃣ Trying to trust the certificate for code signing..."

# Find the certificate hash
cert_hash=$(security find-certificate -c "DoomHUD Developer" -Z ~/Library/Keychains/login.keychain-db 2>/dev/null | grep "SHA-1 hash:" | cut -d: -f2 | tr -d ' ')

if [ ! -z "$cert_hash" ]; then
    echo "Found certificate with hash: $cert_hash"
    # Try to trust it
    security set-key-partition-list -S apple-tool:,apple:,codesign: -k "" ~/Library/Keychains/login.keychain-db
    
    # Check again
    cert_check=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")
    if [ ! -z "$cert_check" ]; then
        echo "✅ Success! Certificate is now working:"
        echo "$cert_check"
        echo ""
        echo "You can now use: ./build_app_signed.sh"
        exit 0
    fi
fi

echo "❌ Automatic fix didn't work. Let's clean up and create a proper certificate."
echo ""
echo "The issue is that your certificate and private key aren't properly linked."
echo "Let's delete the existing ones and create a new one properly."
echo ""
echo "Delete existing DoomHUD Developer certificates and create a new one? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Cancelled. You can:"
    echo "1. Try ./build_app.sh (uses ad-hoc signing)"
    echo "2. Or manually fix the certificate in Keychain Access"
    exit 1
fi

# Delete existing certificates
echo "🗑️ Deleting existing DoomHUD Developer certificates..."
security delete-certificate -c "DoomHUD Developer" ~/Library/Keychains/login.keychain-db 2>/dev/null

echo "✨ Now let's create a proper certificate using a different method..."
echo ""

# Use the built-in certificate assistant
echo "Opening Certificate Assistant..."
echo ""
echo "When the Certificate Assistant opens:"
echo "1. Name: DoomHUD Developer"
echo "2. Identity Type: Self Signed Root"  
echo "3. Certificate Type: Code Signing"
echo "4. Check 'Let me override defaults'"
echo "5. Continue through dialogs (defaults are fine)"
echo "6. Make sure 'Keychain' is set to 'login'"
echo "7. Click Create"
echo ""
echo "Press Enter when ready..."
read -r

# Open the certificate assistant directly
open -b com.apple.keychainaccess "/Applications/Utilities/Keychain Access.app"

# Give instructions to open certificate assistant
echo ""
echo "🔓 Keychain Access is open. Now:"
echo "1. Go to: Keychain Access menu > Certificate Assistant > Create a Certificate..."
echo "2. Follow the instructions above"
echo ""
echo "Press Enter when you've created the certificate..."
read -r

# Final check
cert_check=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")
if [ ! -z "$cert_check" ]; then
    echo "🎉 Perfect! Certificate is working:"
    echo "$cert_check"
    echo ""
    echo "You can now use: ./build_app_signed.sh"
else
    echo "❌ Still not working. Let's fall back to ad-hoc signing."
    echo "Use: ./build_app.sh"
    echo ""
    echo "The ad-hoc signing will work, but permissions might not persist"
    echo "when you move the app to /Applications."
fi

echo ""
echo "Done! 🚀"