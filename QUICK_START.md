# Quick Start for iPhone Testing

## ✅ Already Done
- Base URL set to: `http://192.168.1.12:8000`
- Dependencies installed

## What You Need

**Important**: iOS development requires **macOS with Xcode**. Since you're on Linux, you have these options:

### Option A: Use macOS Computer
1. Copy project to Mac
2. Install Xcode from App Store
3. Connect iPhone via USB
4. Run: `flutter run`

### Option B: Test on Android Phone (Works on Linux)
If you have an Android phone, you can test immediately:
```bash
# Connect Android phone via USB
# Enable USB debugging on phone
flutter devices  # Should show your Android phone
flutter run       # Will install on Android
```

## Start Laravel Server

On your Linux computer, run:
```bash
cd /home/rahul/public_html/QMAPS
php artisan serve --host=0.0.0.0 --port=8000
```

Or use the helper script:
```bash
./START_LARAVEL.sh
```

## Verify from iPhone

On your iPhone's Safari, visit:
```
http://192.168.1.12:8000
```

If this works, your iPhone can connect to the API ✅

## Next Steps

**If using Mac:**
1. Make sure iPhone and Mac are on same WiFi
2. Connect iPhone via USB
3. In Flutter project: `flutter run`
4. Trust developer certificate on iPhone when prompted

**If using Android:**
1. Connect Android phone
2. Enable USB debugging
3. Run: `flutter run`

---
**Current IP**: 192.168.1.12
**API URL**: http://192.168.1.12:8000

