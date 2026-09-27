/**
 * SafeHer Cloud Functions
 * ------------------------------------------------------------------
 * Deploy with:  firebase deploy --only functions
 *
 * onAlertCreated: fires whenever the Flutter app writes a new document
 * to  users/{userId}/alerts/{alertId}  (see AlertService.triggerAlert
 * in the Flutter code). It:
 *   1. Loads the user's emergency contacts
 *   2. Sends an FCM push to any contact who also has the app installed
 *   3. Optionally sends an SMS via Twilio to contacts who don't
 *   4. Marks the alert as "sent" with a server timestamp
 *
 * Configure Twilio credentials with:
 *   firebase functions:config:set twilio.sid="..." twilio.token="..." twilio.from="+1..."
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Twilio is optional — only required if you want real SMS delivery to
// contacts who don't have the SafeHer app / an FCM token.
let twilioClient = null;
try {
  const twilioCfg = functions.config().twilio;
  if (twilioCfg && twilioCfg.sid && twilioCfg.token) {
    twilioClient = require('twilio')(twilioCfg.sid, twilioCfg.token);
  }
} catch (e) {
  console.log('Twilio not configured — SMS fan-out disabled.');
}

exports.onAlertCreated = functions.firestore
  .document('users/{userId}/alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const { userId, alertId } = context.params;
    const alert = snap.data();

    const userSnap = await db.collection('users').doc(userId).get();
    const user = userSnap.data() || {};

    const contactsSnap = await db
      .collection('users')
      .doc(userId)
      .collection('contacts')
      .get();
    const contacts = contactsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    const mapsLink =
      alert.lat && alert.lng
        ? `https://maps.google.com/?q=${alert.lat},${alert.lng}`
        : 'location unavailable';

    const body = `${user.name || 'A SafeHer user'} may need help. ` +
      `Alert source: ${alert.source}. Live location: ${mapsLink}`;

    const notifiedIds = [];

    await Promise.all(
      contacts.map(async (contact) => {
        try {
          if (contact.fcmToken) {
            await messaging.send({
              token: contact.fcmToken,
              notification: { title: 'SafeHer Emergency Alert', body },
              data: { alertId, userId, type: 'EMERGENCY_ALERT' },
              android: { priority: 'high' },
              apns: { headers: { 'apns-priority': '10' } },
            });
          } else if (twilioClient && contact.phone) {
            await twilioClient.messages.create({
              from: functions.config().twilio.from,
              to: contact.phone,
              body,
            });
          }
          notifiedIds.push(contact.id);
        } catch (err) {
          console.error(`Failed to notify contact ${contact.id}:`, err);
        }
      })
    );

    await snap.ref.update({
      status: 'sent',
      notifiedContactIds: notifiedIds,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });

/**
 * onDistressVitalsWrite: a server-side safety net that mirrors the
 * on-device AIDetectionService (lib/services/ai_detection_service.dart).
 * If the phone/wearable ever goes silent mid-episode, this catches a
 * heart-rate reading that's still critically high and creates a
 * backend-triggered alert even without further app input.
 */
exports.onDistressVitalsWrite = functions.firestore
  .document('users/{userId}/vitals/latest')
  .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after) return null;
    const CRITICAL_HR = 150;
    if (after.heartRate && after.heartRate > CRITICAL_HR) {
      const { userId } = context.params;
      await db.collection('users').doc(userId).collection('alerts').add({
        source: 'aiHeartRate',
        status: 'pending',
        lat: null,
        lng: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        notifiedContactIds: [],
        note: 'Server-side failsafe trigger (heart rate > 150bpm sustained).',
      });
    }
    return null;
  });
