# GitHub Actions Setup for DoomHUD

This document explains how to set up GitHub Actions to automatically build and release DoomHUD with proper code signing.

## Required Secrets

To enable code signing in GitHub Actions, you need to add these secrets to your repository:

### 1. Export Your Certificate and Private Key

First, export your signing certificate from Keychain Access:

```bash
# Find your certificate
security find-identity -v -p codesigning

# Export certificate and private key as .p12 file
security export -t identities -f pkcs12 -o certificate.p12 -P "your_export_password"
```

When prompted, select your "DoomHUD Developer" certificate and enter an export password.

### 2. Convert Certificate to Base64

```bash
# Convert .p12 file to base64
base64 -i certificate.p12 -o certificate.p12.base64

# Copy the base64 content
cat certificate.p12.base64
```

### 3. Add GitHub Secrets

Go to your repository Settings → Secrets and variables → Actions, then add:

| Secret Name | Description | Value |
|-------------|-------------|-------|
| `MACOS_CERTIFICATE_P12` | Base64-encoded .p12 certificate file | Contents of `certificate.p12.base64` |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the .p12 file | Export password you used |
| `MACOS_CERTIFICATE_NAME` | Certificate name | `DoomHUD Developer` |
| `KEYCHAIN_PASSWORD` | Temporary keychain password | Any secure password (e.g., `temp_keychain_pass`) |

## Workflow Triggers

The GitHub Action will run on:

1. **Tag pushes**: When you create a git tag starting with `v` (e.g., `v1.0.0`)
2. **Manual trigger**: Use "Run workflow" in GitHub Actions tab

## Creating a Release

### Option 1: Using Git Tags (Recommended)

```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

This will automatically:
- Build the app with proper code signing
- Create a GitHub release
- Attach the signed app as a ZIP file

### Option 2: Manual Workflow

1. Go to GitHub Actions tab in your repository
2. Select "Build and Release DoomHUD" workflow
3. Click "Run workflow"
4. Set "Create a release" to `true`

## Build Process

The GitHub Action will:

1. Set up macOS runner with latest Xcode
2. Cache Swift packages for faster builds
3. Import your signing certificate into a temporary keychain
4. Run your `build_app_signed.sh` script with proper signing
5. Create a ZIP archive of the built app
6. Upload build artifacts
7. Create a GitHub release (if triggered by tag or manual release)

## Security Notes

- Certificates are imported into a temporary keychain that's destroyed after the build
- Your private key never leaves GitHub's secure environment
- The .p12 file is base64-encoded and stored as an encrypted secret

## Troubleshooting

### Certificate Issues
- Ensure your certificate is valid and not expired
- Verify the certificate name matches exactly
- Check that the export password is correct

### Build Failures
- Check the Actions logs for specific errors
- Ensure all dependencies are properly declared in Package.swift
- Verify the build script works locally first

### Permission Issues
- The built app will still require users to grant permissions manually
- Include clear installation instructions in your releases

## Local Testing

Before pushing tags, test your build locally:

```bash
./build_app_signed.sh
```

This ensures the same process will work in GitHub Actions.