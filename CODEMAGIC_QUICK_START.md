# Codemagic Quick Start Guide

## ✅ You're Already Set Up!

Your project already has `codemagic.yaml` configured. Here's how to use it:

## Step 1: Sign Up for Codemagic (Free)

1. Go to: **https://codemagic.io/signup**
2. Sign up with:
   - GitHub account (recommended)
   - GitLab account
   - Bitbucket account
   - Or email

**Free Tier Includes**:
- ✅ 500 build minutes/month
- ✅ Mac Mini M1 builders
- ✅ Public repository builds (unlimited)
- ✅ Usually enough for 10-15 iOS builds

## Step 2: Connect Your Repository

1. After login, click **"Add application"**
2. Select your Git provider (GitHub/GitLab/Bitbucket)
3. Find and select your `qmaps_flutter` repository
4. Click **"Finish"**

Codemagic will automatically detect your `codemagic.yaml` file! ✅

## Step 3: Choose Your Build Workflow

You have 3 workflows available:

### Option A: Simple Release Build (Easiest for Testing)
**Workflow**: `ios-simple-release`
- ✅ No code signing required
- ✅ Fast build (~10-15 minutes)
- ✅ Perfect for testing with AltStore/Sideloadly
- ✅ Download `.app` file

**Use this if**: You want to test on your iPhone quickly without App Store

### Option B: Debug Build
**Workflow**: `ios-debug-workflow`
- ✅ No code signing required
- ✅ Fast build
- ✅ Debug version

**Use this if**: You need to debug the app

### Option C: App Store Build (For Distribution)
**Workflow**: `ios-workflow`
- ✅ Full code signing
- ✅ App Store ready `.ipa`
- ⚠️ Requires App Store Connect setup

**Use this if**: You want to publish to App Store or TestFlight

## Step 4: Start Your First Build

1. Click **"Start new build"** button
2. Select branch: `main` or `dev` (your code branch)
3. Select workflow: Choose one from above
4. Click **"Start new build"**

Build will start immediately on Codemagic's Mac servers!

## Step 5: Download Your Build

1. Wait for build to complete (10-30 minutes)
2. Once done, go to **"Artifacts"** tab
3. Download:
   - `.ipa` file (for App Store build)
   - `.app` file (for simple release build)

## Step 6: Install on iPhone

### For Simple Release Build (.app file):

**Method 1: Using AltStore (Free)**
1. Install AltStore on your computer: https://altstore.io
2. Connect iPhone via USB
3. Drag `.app` file to AltStore
4. AltStore will install on your iPhone

**Method 2: Using Sideloadly (Windows/Mac)**
1. Download: https://sideloadly.io
2. Connect iPhone via USB
3. Open Sideloadly
4. Select your `.app` file
5. Click "Start" to install

### For App Store Build (.ipa file):

**Method 1: TestFlight**
1. Upload `.ipa` to App Store Connect
2. Add to TestFlight
3. Install TestFlight app on iPhone
4. Download your app from TestFlight

**Method 2: Direct Install**
- Use tools like AltStore or Sideloadly (same as above)

## Troubleshooting

### Build Fails?
- Check build logs in Codemagic dashboard
- Common issues:
  - Dependencies missing → Ensure `pubspec.yaml` has all packages
  - Pod install fails → Check iOS folder
  - Code signing → Use `ios-simple-release` workflow instead

### Code Signing Errors?
- Use `ios-simple-release` workflow (no signing required)
- For App Store: Set up App Store Connect API key in Codemagic settings

### Can't Install on iPhone?
- Make sure iPhone is connected
- Trust computer on iPhone
- For AltStore: Enable "Untrusted Enterprise Developer" in iPhone settings

## Environment Variables (Optional)

If you want to customize build behavior, add these in Codemagic app settings:

```
API_BASE_URL=https://stageqmaps.aipopuli.com
```

## Pro Tips

1. **Automatic Builds**: Set up webhooks to build on every push
2. **Notifications**: Codemagic will email you when build completes
3. **Build History**: All builds are saved in dashboard
4. **Free Tier**: Usually enough for personal projects

## Update Email in Config

Edit `codemagic.yaml` line 40:
```yaml
recipients:
  - your-actual-email@gmail.com  # Change this!
```

## Summary

✅ **You're ready!** Just:
1. Sign up at codemagic.io
2. Connect your repo
3. Start a build
4. Download and install on iPhone

**Recommended first build**: Use `ios-simple-release` workflow (no code signing needed)

---

**Need Help?**
- Codemagic Docs: https://docs.codemagic.io
- Codemagic Community: https://codemagicio.slack.com

