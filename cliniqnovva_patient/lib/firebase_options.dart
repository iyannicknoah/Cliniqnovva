// Regenerated 2026-08-19 by `flutterfire configure --project=clinicnovva1
// --platforms=android,ios,web`, pointed at the real Cliniqnovva Firebase
// project the user created — supersedes the 2026-08-08 placeholder that
// borrowed the web dashboard's own then-temporary `risingacademy-801eb`
// config. Real android/ios/web apps are now registered under this project
// for `rw.cliniqnovva.cliniqnovva_patient` (`google-services.json` was also
// written to `android/app/`; no `GoogleService-Info.plist` was generated for
// iOS since this environment has no Xcode to place it into the ios project
// — fetch it from the Firebase console before an actual iOS build).

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

  // Reuses the web dashboard's registered web app (same temporary project —
  // see file header) purely so this app can boot in a browser for local
  // testing; the patient app has no web app of its own registered.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBrthv-8YFRvIlOd-10KeyYGHbY2SHLB_A',
    appId: '1:813219606331:web:b3bee66aabbcc11be0911e',
    messagingSenderId: '813219606331',
    projectId: 'clinicnovva1',
    authDomain: 'clinicnovva1.firebaseapp.com',
    storageBucket: 'clinicnovva1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHsI5B0ImLjl-OjvNAIxB_vgqt-xsSCno',
    appId: '1:813219606331:android:1a91110c87760007e0911e',
    messagingSenderId: '813219606331',
    projectId: 'clinicnovva1',
    storageBucket: 'clinicnovva1.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC061NFDlksl_h4vOYwhwyaAs6aMOUEpNs',
    appId: '1:813219606331:ios:9c697fe8c2e81b48e0911e',
    messagingSenderId: '813219606331',
    projectId: 'clinicnovva1',
    storageBucket: 'clinicnovva1.firebasestorage.app',
    iosClientId: '813219606331-1fklh4sscph8niiuv23hc95d5u7vlvco.apps.googleusercontent.com',
    iosBundleId: 'rw.cliniqnovva.cliniqnovvaPatient',
  );
}
