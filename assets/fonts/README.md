# SF Pro Fonts Setup

This directory should contain the SF Pro font files for cross-platform support.

## Required Font Files

Place the following font files in this directory:

### SF Pro Text (for body text):
- `SF-Pro-Text-Regular.otf` (weight: 400)
- `SF-Pro-Text-Medium.otf` (weight: 500)
- `SF-Pro-Text-Semibold.otf` (weight: 600)
- `SF-Pro-Text-Bold.otf` (weight: 700)

### SF Pro Display (for headings):
- `SF-Pro-Display-Regular.otf` (weight: 400)
- `SF-Pro-Display-Medium.otf` (weight: 500)
- `SF-Pro-Display-Semibold.otf` (weight: 600)
- `SF-Pro-Display-Bold.otf` (weight: 700)

## Where to Get SF Pro Fonts

**Important:** Apple's SF Pro fonts are proprietary. You need to obtain them legally:

1. **For Apple Developers:**
   - Download from Apple Developer website (requires Apple Developer account)
   - Available at: https://developer.apple.com/fonts/

2. **Licensing Note:**
   - SF Pro fonts are licensed for use in software running on Apple's operating systems
   - For cross-platform use, ensure you have proper licensing rights
   - Consider using open-source alternatives if licensing is a concern

## Alternative: Open Source Fonts

If you cannot use SF Pro fonts due to licensing, consider these alternatives:
- **Inter** - Similar design, open source (https://rsms.me/inter/)
- **Roboto** - Android's default font, open source
- **Noto Sans** - Google's font, open source

To use an alternative, update the font family names in:
- `lib/theme/app_theme.dart` (change `SF Pro Text` and `SF Pro Display`)
- `pubspec.yaml` (update font family names and file paths)

## After Adding Fonts

1. Run `flutter pub get` to refresh dependencies
2. Run `flutter clean` (optional, for clean build)
3. Restart your app

The fonts will now be available on all platforms (iOS, Android, Web, Desktop).

