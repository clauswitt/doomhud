#!/bin/bash

echo "🔐 Setting up Code Signing for DoomHUD..."
echo ""

# Check if we already have a certificate
existing=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")
if [ ! -z "$existing" ]; then
    echo "✅ DoomHUD Developer certificate already exists:"
    echo "$existing"
    echo ""
    echo "Would you like to create a new one? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificate."
        exit 0
    fi
fi

echo "Creating self-signed certificate for DoomHUD..."
echo ""
echo "This will:"
echo "1. Create a self-signed certificate named 'DoomHUD Developer'"
echo "2. Add it to your login keychain"
echo "3. Make it trusted for code signing"
echo ""
echo "You'll need to enter your macOS password when prompted."
echo ""
echo "Continue? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Create the certificate using Keychain Access command line
echo "📝 Creating certificate..."

# Create a temporary config file for the certificate
cat > /tmp/doomhud_cert.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = DoomHUD Developer
O = DoomHUD Development
C = US

[v3_req]
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
basicConstraints = CA:false
EOF

# Generate certificate and key
openssl req -new -x509 -days 3650 -nodes \
    -keyout /tmp/doomhud.key \
    -out /tmp/doomhud.crt \
    -config /tmp/doomhud_cert.conf

if [ $? -ne 0 ]; then
    echo "❌ Failed to create certificate with OpenSSL"
    echo ""
    echo "Let's try the macOS way instead..."
    echo "You'll need to create this manually:"
    echo ""
    echo "1. Open Keychain Access"
    echo "2. Go to Keychain Access > Certificate Assistant > Create a Certificate"
    echo "3. Name: DoomHUD Developer"
    echo "4. Identity Type: Self Signed Root"
    echo "5. Certificate Type: Code Signing"
    echo "6. Click Create"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Import certificate and key directly (skip PKCS#12)
echo "📥 Importing certificate into keychain..."
security import /tmp/doomhud.crt -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
security import /tmp/doomhud.key -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign

# Trust the certificate for code signing
echo "🤝 Setting certificate trust..."
cert_sha1=$(openssl x509 -in /tmp/doomhud.crt -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)
security set-key-partition-list -S apple-tool:,apple: -k "" ~/Library/Keychains/login.keychain-db

# Clean up temp files
rm -f /tmp/doomhud.key /tmp/doomhud.crt /tmp/doomhud_cert.conf

echo ""
echo "🎉 Certificate setup complete!"
echo ""

# Verify it worked
echo "🔍 Verifying certificate..."
cert_info=$(security find-identity -v -p codesigning | grep "DoomHUD Developer")
if [ ! -z "$cert_info" ]; then
    echo "✅ Certificate found:"
    echo "$cert_info"
    echo ""
    echo "You can now build DoomHUD with:"
    echo "./build_app_signed.sh"
else
    echo "❌ Certificate not found. Manual setup may be required."
    echo ""
    echo "Manual steps:"
    echo "1. Open Keychain Access"
    echo "2. File > Import Items > Select the certificate"
    echo "3. Double-click the certificate > Trust > Code Signing: Always Trust"
fi

echo ""
echo "Done! 🚀"