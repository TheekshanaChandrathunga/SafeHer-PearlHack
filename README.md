# SafeHer

SafeHer is an AI- and IoT-based smart women safety system built with Flutter,
Firebase, and a simulated ESP32 wearable.

## Project layout

- `safeher_flutter/` is the complete application. It contains the splash screen,
	home dashboard, contacts, location, settings, SOS alert flow, Firebase
	services, Cloud Functions, and Wokwi integration.
- The root `lib/` is a small Firebase integration shell retained for compatibility.
	Run the application from `safeher_flutter/`.
- `safeher_flutter/wokwi_simulation/` contains the ESP32/Wokwi firmware and
	wiring files.

## Run the full application

From the repository root in PowerShell:

```powershell
cd safeher_flutter
flutter pub get
flutter run -d chrome
```

To serve the app at the fixed local URL used during development:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3007
```

Then open <http://127.0.0.1:3007/>.

The app also supports Android, iOS, Windows, macOS, and Linux. Native Firebase
desktop builds require the platform SDK download to complete successfully.

## Firebase setup

From `safeher_flutter/`:

```powershell
firebase login
flutterfire configure
firebase deploy --only firestore:rules,functions
```

Enable Anonymous Authentication and Firestore in the Firebase console before
running the app. `flutterfire configure` regenerates
`safeher_flutter/lib/firebase_options.dart` with the selected project's values.

## Wokwi simulation

The simulated wearable writes heart-rate, movement, and risk readings to
Firestore. Copy the files in `safeher_flutter/wokwi_simulation/` into a Wokwi
ESP32 project, set the Firebase API key and project ID in `sketch.ino`, then
start the simulation. The Flutter dashboard reads the device document in real
time and routes detected risk into the existing SOS flow.

See [safeher_flutter/README.md](safeher_flutter/README.md) for the full Firebase
configuration, AI detection behavior, alert data flow, and production gaps.
For simulator-specific setup and test scenarios, see
[safeher_flutter/SETUP_AND_TESTING.md](safeher_flutter/SETUP_AND_TESTING.md).
# safeher

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
