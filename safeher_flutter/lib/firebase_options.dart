import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAoyGXOS6TtLtfhnfircMPYHziammJcNyY',
    appId: '1:697045561314:web:2eb6de3cfdc5fad339d3bb',
    messagingSenderId: '697045561314',
    projectId: 'pearlhack-94473',
    authDomain: 'pearlhack-94473.firebaseapp.com',
    storageBucket: 'pearlhack-94473.firebasestorage.app',
    measurementId: 'G-9DRLC5G2H7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAoyGXOS6TtLtfhnfircMPYHziammJcNyY',
    appId: '1:697045561314:web:2eb6de3cfdc5fad339d3bb',
    messagingSenderId: '697045561314',
    projectId: 'pearlhack-94473',
    storageBucket: 'pearlhack-94473.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAoyGXOS6TtLtfhnfircMPYHziammJcNyY',
    appId: '1:697045561314:web:2eb6de3cfdc5fad339d3bb',
    messagingSenderId: '697045561314',
    projectId: 'pearlhack-94473',
    storageBucket: 'pearlhack-94473.firebasestorage.app',
    iosBundleId: 'com.safeher.app',
  );
}
