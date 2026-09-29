/*
 * SafeHer - ESP32 IoT SIMULATION (Wokwi)
 * ---------------------------------------------------------------
 * ALL READINGS ARE SIMULATED. No physical sensor (MAX30102,
 * accelerometer, etc.) exists. Thresholds are illustrative test
 * values, NOT medically validated emergency criteria.
 *
 * The real SafeHer Flutter app uses Cloud FIRESTORE (not the
 * Realtime Database), so this firmware writes to Firestore's REST
 * API directly, to the SAME document the app listens to:
 *   sensor_readings/safeher-01   (see FirebaseService.watchDeviceSensor)
 *
 * Flow: ESP32 (Wokwi) -> Wi-Fi -> Firebase Auth (anonymous)
 *       -> Firestore REST API -> Flutter app (existing Firebase project)
 *
 * Library needed (Wokwi libraries.txt): ArduinoJson
 * Live project: https://wokwi.com/projects/476428315577445377
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <time.h>

// ===================== USER CONFIGURATION ======================
// Set to 0 to use the potentiometer and MPU6050, or use scenarios 1-4
// for repeatable alert testing without changing the hardware inputs.
#define SCENARIO 0

#define POT_PIN 34
#define MPU_SDA 21
#define MPU_SCL 22

// --- Firebase placeholders (fill from Firebase console) ---
#define FIREBASE_API_KEY  "AIzaSyApMvAMKqrjXNXB4eJXFAn0KfsoSeMovzQ"
// Firebase project ID, e.g. "safeher-app" (Project settings > General)
#define FIREBASE_PROJECT_ID "pearlhack-94473"

#define DEVICE_ID          "safeher-01"
// Firestore document path the Flutter app listens to (unchanged app-side path)
#define FIRESTORE_DOC_PATH "sensor_readings/" DEVICE_ID

// --- Wi-Fi (Wokwi guest network) ---
#define WIFI_SSID         "Wokwi-GUEST"
#define WIFI_PASSWORD     ""

// --- Illustrative test thresholds (easy to change) ---
const int HR_HIGH_THRESHOLD = 120;   // bpm, test value only
const int HR_LOW_THRESHOLD  = 45;    // bpm, test value only

// --- Timing ---
const unsigned long SEND_INTERVAL_MS   = 3000;
const unsigned long TOKEN_MARGIN_MS    = 60UL * 1000UL;  // refresh 60 s early
const unsigned long WIFI_RETRY_MS      = 10000;
const unsigned long NTP_WAIT_MS        = 15000;          // time to wait for NTP sync
// ===============================================================

String idToken = "";
String refreshToken = "";
unsigned long tokenExpiresAtMs = 0;
unsigned long lastSendMs = 0;
unsigned long inactiveSeconds = 0;
bool timeSynced = false;
Adafruit_MPU6050 mpu;

// ---------------------------------------------------------------
// Wi-Fi
// ---------------------------------------------------------------
bool ensureWifi() {
  if (WiFi.status() == WL_CONNECTED) return true;
  Serial.println("[WiFi] Disconnected. Reconnecting...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD, 6);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_RETRY_MS) {
    delay(250);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[WiFi] Connected, IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  Serial.println("[WiFi] Reconnect failed, will retry.");
  return false;
}

// ---------------------------------------------------------------
// NTP time sync (needed so we can stamp each write with a real
// RFC3339 timestamp; Firestore REST has no ".sv"-style placeholder
// like the Realtime Database does).
// ---------------------------------------------------------------
void syncTime() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("[Time] Syncing via NTP");
  unsigned long start = millis();
  time_t now = time(nullptr);
  while (now < 1700000000 && millis() - start < NTP_WAIT_MS) {
    delay(250);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println();
  timeSynced = now >= 1700000000;
  if (!timeSynced) {
    Serial.println("[Time] NTP sync failed; timestamps will be inaccurate.");
  }
}

// RFC3339 UTC timestamp, e.g. 2026-09-29T12:34:56Z (required by Firestore's
// timestampValue field type)
String rfc3339Now() {
  time_t now = time(nullptr);
  struct tm tmInfo;
  gmtime_r(&now, &tmInfo);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &tmInfo);
  return String(buf);
}

// ---------------------------------------------------------------
// HTTPS helper. Returns HTTP status code (<=0 on transport error).
// NOTE: setInsecure() skips certificate validation. Acceptable for a
// simulation demo only; use a pinned root CA in any real deployment.
// ---------------------------------------------------------------
int httpsRequest(const char* method, const String& url, const String& body,
                 const char* contentType, const char* bearerToken, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) return -1;
  http.addHeader("Content-Type", contentType);
  if (bearerToken != nullptr) {
    http.addHeader("Authorization", String("Bearer ") + bearerToken);
  }
  int code = http.sendRequest(method, body);
  response = (code > 0) ? http.getString() : http.errorToString(code);
  http.end();
  return code;
}

// ---------------------------------------------------------------
// Firebase Authentication (REST) - same anonymous-auth pattern the
// Flutter app itself uses (FirebaseService.ensureSignedIn), just
// called from firmware instead of Dart.
// ---------------------------------------------------------------
bool storeTokens(const String& resp, const char* idKey, const char* refreshKey,
                 const char* expiresKey) {
  JsonDocument doc;
  if (deserializeJson(doc, resp)) {
    Serial.println("[Auth] Could not parse auth response.");
    return false;
  }
  const char* id = doc[idKey];
  const char* rt = doc[refreshKey];
  const char* exp = doc[expiresKey];
  if (!id || !rt || !exp) {
    Serial.println("[Auth] Auth response missing token fields.");
    return false;
  }
  idToken = id;
  refreshToken = rt;
  tokenExpiresAtMs = millis() + (unsigned long)atol(exp) * 1000UL;
  return true;
}

bool signInAnonymously() {
  Serial.println("[Auth] Signing in anonymously...");
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=") + FIREBASE_API_KEY;
  String resp;
  int code = httpsRequest("POST", url, "{\"returnSecureToken\":true}", "application/json", nullptr, resp);
  if (code != 200) {
    Serial.printf("[Auth] Sign-in failed (HTTP %d): %s\n", code, resp.c_str());
    if (resp.indexOf("ADMIN_ONLY_OPERATION") >= 0 || resp.indexOf("OPERATION_NOT_ALLOWED") >= 0)
      Serial.println("[Auth] Hint: enable Anonymous provider in Firebase Console > Authentication.");
    if (resp.indexOf("API key not valid") >= 0)
      Serial.println("[Auth] Hint: check FIREBASE_API_KEY.");
    return false;
  }
  bool ok = storeTokens(resp, "idToken", "refreshToken", "expiresIn");
  if (ok) Serial.println("[Auth] Signed in.");
  return ok;
}

bool refreshIdToken() {
  if (refreshToken.length() == 0) return false;
  Serial.println("[Auth] Refreshing ID token...");
  String url = String("https://securetoken.googleapis.com/v1/token?key=") + FIREBASE_API_KEY;
  String body = String("grant_type=refresh_token&refresh_token=") + refreshToken;
  String resp;
  int code = httpsRequest("POST", url, body, "application/x-www-form-urlencoded", nullptr, resp);
  if (code != 200) {
    Serial.printf("[Auth] Refresh failed (HTTP %d): %s\n", code, resp.c_str());
    return false;
  }
  bool ok = storeTokens(resp, "id_token", "refresh_token", "expires_in");
  if (ok) Serial.println("[Auth] Token refreshed.");
  return ok;
}

bool ensureAuth() {
  bool haveToken = idToken.length() > 0;
  bool expiring = haveToken && (long)(millis() - (tokenExpiresAtMs - TOKEN_MARGIN_MS)) >= 0;
  if (haveToken && !expiring) return true;
  if (haveToken && expiring && refreshIdToken()) return true;
  idToken = ""; refreshToken = "";
  return signInAnonymously();
}

// ---------------------------------------------------------------
// Simulated sensor data
// ---------------------------------------------------------------
struct Reading {
  int heartRate;
  const char* movement;   // "normal" | "unusual" | "inactive"
  bool risk;
  const char* reason;
};

Reading generateReading() {
  Reading r;
  if (SCENARIO != 0) {
    switch (SCENARIO) {
      case 1:  r.heartRate = random(130, 156); r.movement = "normal";   break;
      case 2:  r.heartRate = random(30, 43);   r.movement = "normal";   break;
      case 3:  r.heartRate = random(95, 116);  r.movement = "unusual";  break;
      default: r.heartRate = random(58, 68);   r.movement = "inactive"; break;
    }
  } else {
    sensors_event_t accel, gyro, temp;
    mpu.getEvent(&accel, &gyro, &temp);
    const float magnitude = sqrt(
        accel.acceleration.x * accel.acceleration.x +
        accel.acceleration.y * accel.acceleration.y +
        accel.acceleration.z * accel.acceleration.z);
    r.heartRate = map(analogRead(POT_PIN), 0, 4095, 45, 160);
    r.movement = magnitude > 14.0 ? "unusual" : "normal";
  }

  if (strcmp(r.movement, "inactive") == 0) inactiveSeconds += SEND_INTERVAL_MS / 1000;
  else inactiveSeconds = 0;

  // Illustrative test rules (not medically validated)
  r.risk = false;
  r.reason = "none";
  if (r.heartRate >= HR_HIGH_THRESHOLD)          { r.risk = true; r.reason = "high_heart_rate"; }
  else if (r.heartRate <= HR_LOW_THRESHOLD)      { r.risk = true; r.reason = "low_heart_rate"; }
  else if (strcmp(r.movement, "unusual") == 0)   { r.risk = true; r.reason = "unusual_movement"; }
  else if (inactiveSeconds >= 15)                { r.risk = true; r.reason = "prolonged_inactivity"; }
  return r;
}

// ---------------------------------------------------------------
// Firestore write. PATCH with no updateMask fully replaces the
// document's fields, which is what we want for a "latest reading"
// doc (same intent as the app's own vitals/latest document).
// ---------------------------------------------------------------
bool sendReading(const Reading& r) {
  JsonDocument doc;
  JsonObject fields = doc["fields"].to<JsonObject>();
  fields["device_id"]["stringValue"] = DEVICE_ID;
  fields["heart_rate"]["doubleValue"] = r.heartRate;
  fields["movement"]["stringValue"] = r.movement;
  fields["risk_detected"]["booleanValue"] = r.risk;
  fields["risk_reason"]["stringValue"] = r.reason;
  fields["inactive_seconds"]["integerValue"] = String(inactiveSeconds);
  fields["scenario"]["integerValue"] = String(SCENARIO);
  fields["simulated"]["booleanValue"] = true;   // clearly marks data as simulated
  fields["timestamp"]["timestampValue"] = timeSynced ? rfc3339Now() : "1970-01-01T00:00:00Z";

  String body;
  serializeJson(doc, body);

  String url = String("https://firestore.googleapis.com/v1/projects/") + FIREBASE_PROJECT_ID +
               "/databases/(default)/documents/" + FIRESTORE_DOC_PATH;
  String resp;
  int code = httpsRequest("PATCH", url, body, "application/json", idToken.c_str(), resp);

  if (code == 200) return true;

  Serial.printf("[DB] Write failed (HTTP %d): %s\n", code, resp.c_str());
  if (code == 401) {
    Serial.println("[DB] Token rejected/expired. Will reauthenticate.");
    idToken = "";
  } else if (code == 403 || resp.indexOf("PERMISSION_DENIED") >= 0) {
    Serial.println("[DB] Hint: check Firestore rules for sensor_readings.");
  } else if (code == 404 || resp.indexOf("NOT_FOUND") >= 0) {
    Serial.println("[DB] Hint: check FIREBASE_PROJECT_ID.");
  }
  return false;
}

// ---------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("=== SafeHer ESP32 SIMULATION (readings are NOT real sensor data) ===");
  Serial.printf("Scenario: %d | Device: %s\n", SCENARIO, DEVICE_ID);
  randomSeed(esp_random());

  Wire.begin(MPU_SDA, MPU_SCL);
  if (!mpu.begin()) {
    Serial.println("[Sensor] MPU6050 not found; movement readings unavailable.");
  } else {
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    Serial.println("[Sensor] MPU6050 ready.");
  }

  if (ensureWifi()) syncTime();
}

void loop() {
  if (millis() - lastSendMs < SEND_INTERVAL_MS) return;
  lastSendMs = millis();

  Reading r = generateReading();
  Serial.printf("[SIM] HR=%d bpm | movement=%s | inactive=%lus | risk=%s (%s)\n",
                r.heartRate, r.movement, inactiveSeconds,
                r.risk ? "YES" : "no", r.reason);

  if (!ensureWifi()) return;
  if (!timeSynced) syncTime();
  if (!ensureAuth()) return;

  if (sendReading(r)) {
    Serial.println("[DB] Write OK");
  }
}
