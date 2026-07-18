import 'package:flutter/material.dart';

import 'core/config/flavor_config.dart';
import 'app.dart';

// TODO(Phase 1): call Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// here once `flutterfire configure` has been run against the cliniqnovva-staging project
// and firebase_options_staging.dart exists.
void main() {
  FlavorConfig(
    flavor: Flavor.staging,
    apiBaseUrl: 'https://api-staging.cliniqnovva.rw',
    firebaseProjectId: 'cliniqnovva-staging',
  );
  runApp(const CliniqnovvaApp());
}
