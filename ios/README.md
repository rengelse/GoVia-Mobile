# iOS runner

The shared Flutter/Dart code is iOS-compatible. Generate the native Xcode shell on macOS with:

```bash
./tool/bootstrap_ios.sh
```

The script adds the camera/location usage descriptions required by QR scanning and navigation. GitHub APK self-update is Android-only; iOS updates must use App Store/TestFlight.
