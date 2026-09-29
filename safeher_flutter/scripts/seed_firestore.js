const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'pearlhack-94473';
const USER_ID = process.env.SAFEHER_USER_ID || 'demo-user-001';

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Missing GOOGLE_APPLICATION_CREDENTIALS.');
  console.error('1) Download the Firebase Admin SDK JSON from Firebase Console > Project settings > Service accounts');
  console.error('2) Set GOOGLE_APPLICATION_CREDENTIALS to that file path');
  console.error('Example:');
  console.error('   set GOOGLE_APPLICATION_CREDENTIALS=C:\\path\\to\\serviceAccountKey.json');
  process.exit(1);
}

const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);

admin.initializeApp({
  credential: admin.cert(serviceAccount),
  projectId: PROJECT_ID,
});

const db = getFirestore();

async function seedFirestore() {
  const userRef = db.collection('users').doc(USER_ID);

  await userRef.set(
    {
      createdAt: FieldValue.serverTimestamp(),
      name: 'Demo User',
      phone: '+1234567890',
      fcmToken: 'demo-token',
      settings: {
        soundAlert: true,
        autoCall: true,
        shareLocation: true,
        notifyAuthorities: true,
        autoNightMode: true,
      },
    },
    { merge: true }
  );

  await userRef.collection('contacts').doc('contact-1').set({
    name: 'Emergency Contact',
    phone: '+1234567891',
    relationship: 'Family',
    fcmToken: 'demo-contact-token',
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await userRef.collection('vitals').doc('latest').set({
    heartRate: 78,
    accelMagnitude: 0.4,
    battery: 92,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await userRef.collection('alerts').doc('alert-demo-001').set({
    createdAt: FieldValue.serverTimestamp(),
    status: 'pending',
    source: 'manual',
    lat: 6.9271,
    lng: 79.8612,
    notifiedContactIds: ['contact-1'],
    message: 'Demo alert created for SafeHer testing',
  }, { merge: true });

  await db.collection('sensor_readings').doc('safeher-01').set({
    device_id: 'safeher-01',
    heart_rate: 82,
    movement: 'normal',
    risk_detected: false,
    timestamp: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('Firestore seed complete.');
  console.log('Collections created/updated: users, sensor_readings');
  console.log('Subcollections created/updated: users/' + USER_ID + '/contacts, vitals, alerts');
}

seedFirestore()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exit(1);
  });
