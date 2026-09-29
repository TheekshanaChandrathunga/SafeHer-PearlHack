# SafeHer — ESP32 (Wokwi) Simulation Integration

Adds a simulated wearable to the existing SafeHer app **without** changing
its architecture: same Firestore project, same emergency workflow
(`AlertService` → `AlertCountdownScreen` → Firestore `alerts`), same UI
screens. Only 4 files are modified and 1 file is new — see the diff summary
at the bottom.

Live Wokwi project: https://wokwi.com/projects/476428315577445377

The live Wokwi project must use the repository versions of
`wokwi_simulation/sketch.ino` and `wokwi_simulation/libraries.txt`. The
original online sketch only printed BPM and accelerometer values; it did not
connect to Firebase, so the Flutter app could not receive those readings.

**Important correction to the original brief:** the app uses **Cloud
Firestore**, not the Realtime Database. Everything below targets Firestore.
There is also an orphaned duplicate `lib/` at the repo root (outside
`safeher_flutter/`) with no screens — it looks unused; this integration
only touches `safeher_flutter/`.

## 1. How it fits together

```
Wokwi ESP32 sketch → Firebase Auth (anonymous, REST)
                    → Firestore doc: sensor_readings/safeher-01
                    → FirebaseService.watchDeviceSensor() (Flutter, existing service)
                    → HomeScreen: shows HR / movement / connection status
                    → debounced risk check → "Are you okay?" dialog
                    → existing AlertCountdownScreen → existing AlertService
                    → existing Firestore `alerts` + Cloud Function fan-out
```

The app's own on-device demo (`AIDetectionService`, the "Simulate AI Alert"
button) is untouched and still works — the ESP32 feed is an **additional**,
clearly-labeled source, not a replacement.

## 2. Firebase Console setup

1. **Anonymous Authentication** — Authentication → Sign-in method → enable
   **Anonymous**. (The app already requires this for its own sign-in; the
   simulated ESP32 reuses the same mechanism with its own anonymous user.)
2. **Web API key** — Project settings → General → Web API Key.
3. **Project ID** — same page, "Project ID" (e.g. `safeher-app-1234`).
4. **Deploy the updated rules**:
   ```powershell
   cd safeher_flutter
   firebase deploy --only firestore:rules
   ```
   The `sensor_readings/{deviceId}` block allows the simulator to write its
   validated reading and allows the app to read it in real time.
5. Run `flutterfire configure` if you haven't already, so
   `lib/firebase_options.dart` has real (non-placeholder) values.

## 3. Wokwi firmware

Files: `sketch.ino`, `diagram.json`, `libraries.txt` (attached).

1. Go to [wokwi.com](https://wokwi.com), create a new ESP32 project, and
   replace its `sketch.ino` and `libraries.txt` with the repository versions.
   Keep the existing potentiometer and MPU6050 `diagram.json` wiring.
2. In `sketch.ino`, set:
   - `FIREBASE_API_KEY` → your Web API key
   - `FIREBASE_PROJECT_ID` → your Firebase project ID
3. `#define SCENARIO` selects the test case (0–4, see table below).
4. Start the simulation. The Serial Monitor logs Wi-Fi connection, NTP
   time sync, Firebase sign-in, sensor readings, and each Firestore write
   result. A successful connection prints `[DB] Write OK` every 3 seconds.

The firmware writes a full JSON document every 3 seconds to
`sensor_readings/safeher-01`:

```json
{
  "device_id": "safeher-01",
  "heart_rate": 132,
  "movement": "normal",
  "risk_detected": true,
  "risk_reason": "high_heart_rate",
  "inactive_seconds": 0,
  "scenario": 1,
  "simulated": true,
  "timestamp": "2026-09-29T12:34:56Z"
}
```

`simulated: true` and the `timestamp` (used for staleness) are what the app
relies on to show "Live simulated ESP32 sensor" vs "offline". Certificate
validation is skipped (`setInsecure()`) to keep the sketch simple — fine
for a demo, not for production.

## 4. Flutter changes (exact files)

All paths are relative to `safeher_flutter/`:

| File | Change |
|---|---|
| `lib/models/sensor_reading_model.dart` | **New.** Parses a `sensor_readings/{id}` doc into `EspSensorReading`. |
| `lib/services/firebase_service.dart` | **Modified.** Added `watchDeviceSensor()` — reuses the existing `_db` instance, no duplicate Firebase init. |
| `lib/widgets/vitals_card.dart` | **Modified.** `VitalsRow` gained two optional params (`movementLabel`, `simulated`); existing callers without them behave exactly as before. |
| `lib/screens/home_screen.dart` | **Modified.** Subscribes to the ESP32 stream, shows HR/movement/connection, debounces risk (2 consecutive risky reads, 30s cooldown) before showing "Are you okay?", and reuses the existing `_openCountdown` → `AlertService` path with `AlertSource.aiHeartRate` / `aiMotion`. |
| `firestore.rules` | **Modified.** Added a rule block for `sensor_readings/{deviceId}` (see §2.4). |

Copy each file over the matching path in your project (they're provided
below with their target path preserved), then:

```powershell
cd safeher_flutter
flutter pub get
flutter run -d windows   # or an Android emulator / device
```

The app supports Chrome as well as Android, iOS, Windows, macOS and Linux.
Firebase Authentication and Firestore are initialized for the web build, so
the Wokwi stream can be inspected from Chrome while the simulation is running.

## 5. Testing

### Confirm data reaches Firestore
Firebase Console → Firestore Database → `sensor_readings` → `safeher-01`.
The document should update every ~3 seconds while Wokwi is running.

### Confirm the app receives it
Run the app and open the Home tab. Within a few seconds you should see:
- The heart-rate tile switch from the phone's own demo value to the
  ESP32's value
- A "Movement" tile showing Normal / Unusual / Inactive
- A caption: "Live simulated ESP32 sensor (Wokwi) — not a real wearable"
- If you stop the Wokwi simulation, the caption switches to "…offline"
  after ~10 seconds

### Scenario test cases

| Scenario | Expected `risk_reason` | Expected app behavior |
|---|---|---|
| 0 — Normal | `none` | No prompt; HR/movement update normally |
| 1 — Elevated HR | `high_heart_rate` | After 2 consecutive high readings (~6s), "Are you okay?" dialog appears |
| 2 — Low HR | `low_heart_rate` | Same as above |
| 3 — Unusual movement | `unusual_movement` | Same as above, escalates via `AlertSource.aiMotion` |
| 4 — Prolonged inactivity | `prolonged_inactivity` (after ~15s inactive) | Same as above, escalates via `AlertSource.aiMotion` |

For each: change `SCENARIO` in `sketch.ino`, restart the Wokwi simulation,
and confirm the dialog appears once (not on every 3s tick — that's the
debounce working). Tap "Yes, I'm Okay" to dismiss, or "No, I need help" (or
wait 10s) to confirm it reaches the existing `AlertCountdownScreen` and, on
completion, a new document under `users/{uid}/alerts`.

### Troubleshooting

| Symptom | Likely cause |
|---|---|
| Serial: `Sign-in failed ... OPERATION_NOT_ALLOWED` | Anonymous auth not enabled in Firebase Console |
| Serial: `API key not valid` | Wrong `FIREBASE_API_KEY` |
| Serial: `Write failed (HTTP 403) ... PERMISSION_DENIED` | Rules not deployed, or a field is missing/wrong type — check the JSON shown in the Serial log against §3's example |
| Serial: `Write failed (HTTP 404) ... NOT_FOUND` | Wrong `FIREBASE_PROJECT_ID` |
| App shows no movement/HR tile changing | Wokwi isn't running, the Firestore document is not updating, or `flutterfire configure` wasn't run |
| Dialog never appears in Scenario 1–4 | Check Firestore console — is `risk_detected: true` actually being written? Confirm 2 consecutive writes have it (debounce requirement) |
| Dialog appears repeatedly every few seconds | Cooldown/debounce not taking effect — confirm you're using the provided `home_screen.dart`, not an older copy |
