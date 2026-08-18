// Regenerated 2026-08-19 by `flutterfire configure --project=clinicnovva1
// --platforms=web`, pointed at the real Cliniqnovva Firebase project the
// user created (superseding the 2026-07-20 run against the temporary
// `risingacademy-801eb` project). `web` below is the live config. Only the
// `web` platform was reconfigured here — this app ships web-only (no Staff
// Mobile App, see DESIGN_LANGUAGE.md) — so `android`/`ios` below are still
// leftover from the old temporary project and are dead code in practice
// (this app's `currentPlatform` always resolves `kIsWeb` -> `web`).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBrthv-8YFRvIlOd-10KeyYGHbY2SHLB_A',
    appId: '1:813219606331:web:b3bee66aabbcc11be0911e',
    messagingSenderId: '813219606331',
    projectId: 'clinicnovva1',
    authDomain: 'clinicnovva1.firebaseapp.com',
    storageBucket: 'clinicnovva1.firebasestorage.app',
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCESs1B01TmZ1jl6Ggd4BticYmrBY-LgRw',
    appId: '1:943939108409:android:0029fa7f55ade07c6797e8',
    messagingSenderId: '943939108409',
    projectId: 'risingacademy-801eb',
    storageBucket: 'risingacademy-801eb.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD4YAbDMw-TiwrDIOn-k9snV9grM-CYvHc',
    appId: '1:943939108409:ios:5afcfe8ecc77504b6797e8',
    messagingSenderId: '943939108409',
    projectId: 'risingacademy-801eb',
    storageBucket: 'risingacademy-801eb.firebasestorage.app',
    iosBundleId: 'com.cliniqnovva.cliniqnovva',
  );
}
