# Running QMAPS Flutter App on Your Phone

## Prerequisites

1. **Flutter SDK** - Make sure Flutter is installed on your computer
2. **Android Studio** or **Xcode** (for iOS)
3. **Physical phone** with USB debugging enabled
4. **Computer and phone on the same WiFi network** (for API access)

## Step-by-Step Instructions

### 1. Install Flutter Dependencies

First, navigate to the Flutter project directory and install dependencies:

```bash
cd /home/rahul/public_html/qmaps_flutter
flutter pub get
```

### 2. Configure API Base URL for Phone Access

Since `127.0.0.1` only works on your computer, you need to change it to your computer's IP address.

**Find your computer's IP address:**

**Linux/Mac:**
```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
# OR
hostname -I
```

**Windows:**
```bash
ipconfig
# Look for "IPv4 Address" under your WiFi adapter
```

**Update the base URL in:** `lib/services/auth_service.dart`

Change line 9 from:
```dart
static const String baseUrl = 'http://127.0.0.1:8000';
```

To:
```dart
static const String baseUrl = 'http://YOUR_COMPUTER_IP:8000';
// Example: static const String baseUrl = 'http://192.168.1.100:8000';
```

**Also update in:** `lib/services/task_service.dart` (it uses `AuthService.baseUrl`, so it will automatically use the new URL)

### 3. Ensure Laravel API is Running and Accessible

Make sure your Laravel backend is running and accessible from your phone:

```bash
cd /home/rahul/public_html/QMAPS
php artisan serve --host=0.0.0.0 --port=8000
```

The `--host=0.0.0.0` allows access from other devices on your network.

**Verify API is accessible:**
- From your phone's browser, visit: `http://YOUR_COMPUTER_IP:8000`
- You should see the Laravel welcome page or your app

### 4. Enable USB Debugging on Your Phone

#### For Android:
1. Go to **Settings** > **About Phone**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings** > **Developer Options**
4. Enable **USB Debugging**
5. Connect your phone via USB
6. Accept the USB debugging prompt on your phone

#### For iOS (Mac only):
1. Connect your iPhone via USB
2. Trust the computer when prompted
3. On iPhone: **Settings** > **Privacy & Security** > **Developer Mode** (enable)

### 5. Check Connected Devices

```bash
# For Android
flutter devices
# OR
adb devices

# For iOS (Mac only)
flutter devices
```

You should see your phone listed. If not:
- Make sure USB debugging is enabled
- Try a different USB cable
- Restart ADB: `adb kill-server && adb start-server`

### 6. Build and Run on Phone

#### For Android:
```bash
cd /home/rahul/public_html/qmaps_flutter
flutter run
```

#### For iOS (Mac only):
```bash
cd /home/rahul/public_html/qmaps_flutter
flutter run
```

### 7. Troubleshooting

#### App can't connect to API:
- ✅ Ensure phone and computer are on the **same WiFi network**
- ✅ Check firewall settings (allow port 8000)
- ✅ Verify Laravel is running with `--host=0.0.0.0`
- ✅ Test API from phone browser: `http://YOUR_COMPUTER_IP:8000/api/auth/login`

#### Camera permission issues:
- The app will request camera permission when you try to scan QR codes
- You can also grant it manually in phone settings

#### Build errors:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### 8. Alternative: Build APK for Android

If you want to install the app directly without USB:

```bash
# Build APK
flutter build apk --release

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk

# Transfer to phone and install
```

### 9. For Production Testing

If you want to use the staging server instead:

In `lib/services/auth_service.dart`, change to:
```dart
static const String baseUrl = 'https://stageqmaps.aipopuli.com';
```

## Quick Checklist

- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] Base URL updated to computer's IP address
- [ ] Laravel running with `--host=0.0.0.0`
- [ ] Phone and computer on same WiFi
- [ ] USB debugging enabled (Android) or Developer Mode (iOS)
- [ ] Phone connected and visible (`flutter devices`)
- [ ] Camera permission granted on phone

## Testing the QR Scanner

1. Open the app on your phone
2. Login with your credentials
3. Tap the "Scan QR Code" button on the home screen
4. Grant camera permission if prompted
5. Scan a QR code containing a location ID
6. Fill out the task creation form
7. Submit the task

The QR code should contain just the location ID number (e.g., `24`) or in format `location_id:24`.

