# Building iOS App Without a Mac

You have several options to build iOS apps without owning a Mac:

## Option 1: Codemagic CI/CD (Recommended - Already Configured! ✅)

You already have `codemagic.yaml` configured! Here's how to use it:

### Setup Steps:

1. **Create Codemagic Account**:
   - Go to: https://codemagic.io
   - Sign up with GitHub/GitLab/Bitbucket (wherever your code is)

2. **Connect Your Repository**:
   - After login, click "Add application"
   - Connect your repository (GitHub/GitLab/Bitbucket)
   - Codemagic will detect the `codemagic.yaml` file automatically

3. **Configure Code Signing**:
   - Go to your app settings in Codemagic
   - Navigate to "Code signing identities"
   - Upload your:
     - **App Store Connect API Key** (or use automatic code signing)
     - **Provisioning profiles** (optional, Codemagic can generate them)

4. **Update codemagic.yaml** (if needed):
   - Update the email in line 40: `your-email@example.com` → your actual email
   - Set App Store Connect credentials (or use environment variables)

5. **Start Build**:
   - Click "Start new build" in Codemagic dashboard
   - Select the `ios-workflow` workflow
   - Your app will be built on Codemagic's Mac servers
   - Download the `.ipa` file when build completes

### Advantages:
- ✅ Free tier: 500 build minutes/month
- ✅ Uses your existing `codemagic.yaml`
- ✅ Automatic code signing available
- ✅ Direct App Store/TestFlight deployment
- ✅ No Mac required!

---

## Option 2: Appcircle (Alternative)

1. **Sign up**: https://appcircle.io
2. **Connect repository**
3. **Configure iOS build**
4. **Download .ipa file**

Free tier available for personal projects.

---

## Option 3: GitHub Actions (Free for Public Repos)

Create `.github/workflows/ios-build.yml`:

```yaml
name: Build iOS

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
          
      - name: Get dependencies
        run: flutter pub get
        
      - name: Install CocoaPods
        run: |
          cd ios
          pod install
          
      - name: Build IPA
        run: flutter build ipa --release --no-codesign
        
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: ios-build
          path: build/ios/ipa/*.ipa
```

**Note**: GitHub Actions requires code signing setup.

---

## Option 4: Remote Mac Services (Paid)

- **MacStadium**: Rent a Mac in the cloud
- **AWS EC2 Mac instances**: Build on AWS
- **MacinCloud**: Dedicated Mac servers

These are more expensive but give you full Mac access.

---

## Option 5: Local Build (Without Full Code Signing)

If you just need to test on your own iPhone without App Store:

### Using GitHub Actions or Codemagic:

1. Build with `--no-codesign` flag
2. Download the `.app` or `.ipa` file
3. Use tools like **AltStore** or **Sideloadly** to install on iPhone

### Manual Installation via Sideloadly:

```bash
# On Codemagic/GitHub Actions, build with:
flutter build ios --release --no-codesign

# Download the build/ios/Release-iphoneos/Runner.app
# Use Sideloadly (Windows/Mac) or AltStore to install
```

---

## Recommended: Update Your Codemagic Config

Let's update your `codemagic.yaml` for easier use:

### Simple Development Build (No Code Signing):

```yaml
workflows:
  ios-simple-build:
    name: iOS Simple Build
    max_build_duration: 30
    instance_type: mac_mini_m1
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Get Flutter packages
        script: |
          flutter pub get
      - name: Install pods
        script: |
          cd ios
          pod install
      - name: Flutter build iOS (no codesign)
        script: |
          flutter build ios --release --no-codesign
    artifacts:
      - build/ios/Release-iphoneos/Runner.app
      - build/ios/ipa/*.ipa
```

### App Store Build (With Code Signing):

Your existing config is good! Just update:
- Email address
- App Store Connect credentials (via environment variables)

---

## Quick Start with Codemagic:

1. **Sign up**: https://codemagic.io/signup
2. **Connect repo**: Add your GitHub/GitLab repository
3. **Start build**: Click "Start new build" → Select `ios-workflow`
4. **Download**: Get your `.ipa` file from build artifacts

**Free tier**: 500 minutes/month (usually enough for ~10-15 builds)

---

## Troubleshooting:

### Code Signing Issues:
- Use Codemagic's automatic code signing (easiest)
- Or upload your certificates manually

### Build Fails:
- Check build logs in Codemagic dashboard
- Ensure all dependencies are in `pubspec.yaml`
- Verify Flutter version compatibility

### Installing on iPhone:
- For development: Use Sideloadly or AltStore with unsigned build
- For App Store: Use TestFlight or direct submission

---

## Summary:

**Best Option**: **Codemagic** (you're already set up!)
- ✅ Free tier available
- ✅ Configuration already exists
- ✅ No Mac needed
- ✅ Professional CI/CD

**Steps**:
1. Sign up at codemagic.io
2. Connect your repository
3. Start a build
4. Download the `.ipa` file

Your `codemagic.yaml` is ready to use! 🚀

