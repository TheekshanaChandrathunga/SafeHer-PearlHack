# SafeHer Setup Guide

SafeHer is a Flutter application with Firebase Authentication, Firestore,
Firebase Cloud Messaging, location access, and a simulated AI sensor service.

## 1. Prerequisites

Install these tools:

- Flutter SDK
- Android Studio and Android SDK (for Android)
- Google Chrome (for web demo)
- Node.js 20 or newer (for Firebase Functions)
- Firebase CLI

Check the local installation:

```powershell
flutter doctor
flutter devices
```

Android license warnings can be fixed with:

```powershell
flutter doctor --android-licenses
```

## 2. Run the UI Demo

From the project directory:

```powershell
cd D:\PearlHack\safeher_flutter
flutter pub get
flutter run -d chrome
```

Keep the terminal open while using the application. Press `q` in that
terminal to stop the application.

The demo includes the dashboard, navigation, simulated vitals, simulated AI
alerts, SOS countdown, location screen, and settings UI.

## 3. Configure Firebase

The current `lib/firebase_options.dart` contains placeholder values. Firebase
must be configured before contacts, settings, alerts, or notifications can
work.

Log in and configure the Flutter app:

```powershell
cd D:\PearlHack\safeher_flutter
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
flutter pub get
```

During `flutterfire configure`, select the Firebase project and enable the
platforms you intend to use. This generates real Firebase options and platform
configuration files.

In the Firebase Console, enable:

1. Authentication -> Sign-in method -> Anonymous
2. Firestore Database -> Create database
3. Cloud Messaging, if push notifications are required

Then run the app again:

```powershell
flutter run -d chrome
```

## 4. Deploy Firebase Backend

Install the Cloud Functions dependencies:

```powershell
cd D:\PearlHack\safeher_flutter\functions
npm install
```

Deploy Firestore rules and Functions from the project root:

```powershell
cd D:\PearlHack\safeher_flutter
firebase deploy --only firestore:rules,functions
```

Twilio is optional. Configure it only when SMS delivery is required:

```powershell
firebase functions:config:set twilio.sid="ACxxxx" twilio.token="xxxx" twilio.from="+1xxxxxxxxxx"
firebase deploy --only functions
```

## 5. Run on Android

Start an emulator from Android Studio, or use:

```powershell
flutter emulators
flutter emulators --launch <emulator-id>
flutter run
```

After `flutterfire configure`, verify that
`android/app/google-services.json` exists. Android location permissions must
also be present in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Use a physical Android device for the most realistic location, phone-call,
and notification testing.

## 6. Current Prototype Limitations

These parts are intentionally simulated or incomplete:

- Wearable sensors and BLE connection are simulated.
- AI readings are generated locally instead of coming from a real device.
- Voice SOS currently opens the SOS flow but does not perform speech
  recognition.
- Fake Call and Share Location actions are placeholders.
- The location screen displays coordinates but does not embed a map.
- Real push notifications require Firebase Cloud Messaging setup.
- Real SMS requires Twilio configuration and deployed Functions.

## 7. Useful Commands

```powershell
flutter analyze
flutter test
flutter clean
flutter pub get
flutter run -d chrome
flutter run -d windows
```

Analyzer warnings do not necessarily prevent the app from running. Fix any
actual errors before release.
