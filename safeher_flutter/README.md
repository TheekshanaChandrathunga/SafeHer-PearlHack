# SafeHer — Flutter + Firebase

AI & IoT-based Smart Women Safety System (Pretty Pixels, KDU — PearlHack Designathon).
This is a complete, runnable Flutter app wired to a real Firebase backend, with a
simulated AI panic-detection engine standing in for the wearable's on-device model.

## What's included

```
lib/
  main.dart                      # app entry, Firebase init, push handler
  firebase_options.dart          # PLACEHOLDER — regenerate with flutterfire configure
  theme/app_theme.dart           # design tokens matching the Figma
  models/                        # Contact, Alert, Vitals data classes
  services/
    firebase_service.dart        # Auth + Firestore + FCM wrapper
    ai_detection_service.dart    # simulated AI panic/motion/fall detector
    location_service.dart        # geolocator wrapper
    alert_service.dart           # orchestrates the SOS pipeline
  screens/                       # Splash, Home, Contacts, Location, Settings,
                                  # Alert countdown, Alert sent
  widgets/                       # SOS hold-button, vitals row
functions/
  index.js                       # Cloud Functions: alert fan-out + failsafe
firestore.rules                  # per-user data isolation
firebase.json / firestore.indexes.json
```

## 1. Firebase project setup

```bash
npm install -g firebase-tools
firebase login
firebase init                       # choose Firestore + Functions, pick/create a project
dart pub global activate flutterfire_cli
flutterfire configure               # regenerates lib/firebase_options.dart for real
```

Enable in the Firebase console:
- **Authentication** → Anonymous (the app signs users in anonymously by default;
  swap to Phone/Email auth for production — the hooks are in `firebase_service.dart`)
- **Firestore Database** → production mode (rules are in `firestore.rules`)
- **Cloud Messaging** → no extra setup needed, just note your server key

Deploy the backend:
```bash
firebase deploy --only firestore:rules,functions
```

(Optional) enable real SMS delivery to contacts without the app installed:
```bash
firebase functions:config:set twilio.sid="ACxxxx" twilio.token="xxxx" twilio.from="+1xxxxxxxxxx"
```

## 2. Flutter app setup

```bash
flutter pub get
flutter run
```

### Google Maps

The Live Tracking screen uses Google Maps. Create a restricted Google Maps
JavaScript API key with the **Maps JavaScript API** enabled, then replace
`YOUR_GOOGLE_MAPS_API_KEY` in `web/index.html`. Restrict the key by HTTP
referrer for the domains where the web app is hosted. The browser must allow
location access for the current-position marker to appear.

Add platform config files after `flutterfire configure`:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Android also needs, in `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```
and in `android/build.gradle`: `classpath 'com.google.gms:google-services:4.4.1'`.

Location permissions: add to `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
and to `ios/Runner/Info.plist` the usual `NSLocationWhenInUseUsageDescription` key.

## 3. How the AI/motion detection works

`AIDetectionService` (lib/services/ai_detection_service.dart) simulates what would
run on the ESP32 wearable / phone in the real product:

1. **Rolling personal baseline** — keeps the last 20 heart-rate readings and computes
   a mean + standard deviation, instead of a fixed global threshold.
2. **Detector 1 — heart-rate spike**: flags when the current reading exceeds
   `baseline + max(20bpm, 2.5σ)`.
3. **Detector 2 — violent motion**: flags when simulated accelerometer magnitude
   exceeds a struggle threshold.
4. **Detector 3 — stillness after spike**: flags a "possible incapacitation" pattern
   (motion spike immediately followed by several ticks of near-zero movement),
   matching the proposal's fall/attack scenario.
5. Requires **3 consecutive abnormal ticks** before escalating to `critical`, so a
   single noisy reading never fires the alarm.
6. On `critical`, `HomeScreen` shows the "Are you okay?" dialog from the mockups.
   No response within 10s (fear/shock impairing action, per the problem statement)
   or a "No" tap escalates straight into the 5-second countdown → alert pipeline.

To replace the simulation with real sensor data, swap `_syntheticStream()` for a
`sensors_plus` `accelerometerEvents` stream and real BLE heart-rate characteristic
notifications from the wearable, feeding the same `_analyse()` method — the
detection logic itself doesn't change.

## 4. Data flow on trigger

```
Manual hold / AI escalation / Voice SOS
        │
        ▼
AlertCountdownScreen (5s, cancellable)
        │ confirmed
        ▼
AlertService.triggerAlert()
        │  grabs GPS fix, writes users/{uid}/alerts/{id}
        ▼
Cloud Function onAlertCreated
        │  loads contacts, sends FCM push (or Twilio SMS fallback)
        ▼
AlertSentScreen shows "Notified ✓" per contact + live tracking link
```

## 5. Known gaps to fill for production

- Replace anonymous auth with phone-number verification (contacts should be
  invited/verified users so `fcmToken` gets populated for push delivery).
- Real wearable firmware (Arduino/ESP32 + heart-rate + accelerometer +
  BLE) per the proposal's hardware section — not included here since this is
  the app/backend half of the system.
- Add `flutter_local_notifications` wiring for foreground FCM display (dependency
  is already in `pubspec.yaml`).
- Add a TensorFlow/scikit-learn-trained model to replace the rule-based
  `_analyse()` thresholds once real labeled sensor data is available.
