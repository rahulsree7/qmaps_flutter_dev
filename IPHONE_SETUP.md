# Running Flutter App on iPhone

## Your Configuration
- **Computer IP**: `192.168.1.12`
- **API URL**: `http://192.168.1.12:8000`
- ✅ Base URL updated in `auth_service.dart`

## Step-by-Step for iPhone

### 1. Start Laravel Server (Accept Connections from Network)

Open a new terminal and run:

```bash
cd /home/rahul/public_html/QMAPS
php artisan serve --host=0.0.0.0 --port=8000
```

**Important**: The `--host=0.0.0.0` allows your iPhone to access the API.

### 2. Verify API is Accessible

From your iPhone's Safari browser, visit:
```
http://192.168.1.12:8000
```

You should see the Laravel welcome page or your app. If not:
- ✅ Make sure iPhone and computer are on the **same WiFi network**
- ✅ Check firewall settings on your computer

### 3. Connect iPhone to Mac/Computer

**For macOS:**
1. Connect iPhone via USB cable
2. On iPhone: Trust this computer (if prompted)
3. On iPhone: Settings > Privacy & Security > Developer Mode (enable if shown)

**Note**: Flutter iOS development requires macOS with Xcode. If you're on Linux, you'll need:
- Use a Mac for iOS development, OR
- Use an Android phone instead

### 4. Check iPhone is Connected

```bash
flutter devices
```

You should see your iPhone listed. If not:
- ✅ Make sure iPhone is unlocked
- ✅ Trust the computer on iPhone
- ✅ Ensure Developer Mode is enabled (if iOS 16+)

### 5. Run on iPhone

```bash
cd /home/rahul/public_html/qmaps_flutter
flutter run
```

Flutter will build and install the app on your iPhone automatically.

### 6. First Time Setup

On your iPhone:
1. **Trust Developer**: Settings > General > VPN & Device Management
2. Trust your developer certificate
3. The app should launch automatically

### 7. Testing the App

1. Login with your credentials
2. The app should connect to `http://192.168.1.12:8000`
3. Test QR scanner: Tap "Scan QR Code" button
4. Grant camera permission when prompted
5. Scan a QR code with location ID

### Troubleshooting

#### "No devices found"
- Make sure iPhone is connected via USB
- Unlock iPhone
- Trust computer on iPhone
- Check: `flutter devices`

#### "Cannot connect to API"
- ✅ iPhone and computer must be on **same WiFi**
- ✅ Laravel running with `--host=0.0.0.0`
- ✅ Test in Safari: `http://192.168.1.12:8000`
- ✅ Check firewall allows port 8000

#### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

#### Code Signing Issues (iOS)
If you see code signing errors, you need to:
1. Open project in Xcode: `open ios/Runner.xcworkspace`
2. Select your team in Signing & Capabilities
3. Or run: `flutter run --no-codesign` (for development only)

### Alternative: Build for iPhone Without USB

If you want to build and transfer manually:

```bash
# Build iOS app
flutter build ios --release

# Then use Xcode to archive and install via TestFlight or ad-hoc
```

---

**Your Current Setup:**
- ✅ Base URL: `http://192.168.1.12:8000`
- ✅ Dependencies installed
- Ready to run!

**Next Steps:**
1. Start Laravel: `php artisan serve --host=0.0.0.0 --port=8000`
2. Connect iPhone
3. Run: `flutter run`

