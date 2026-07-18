import 'package:flutter/material.dart';

import 'core/config/flavor_config.dart';
import 'app.dart';

// TODO(Phase 1): call Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// here once `flutterfire configure` has been run against the cliniqnovva-dev project
// and firebase_options_dev.dart exists.
void main() {
  FlavorConfig(
    flavor: Flavor.dev,
    apiBaseUrl: 'https://api-dev.cliniqnovva.rw',
    firebaseProjectId: 'cliniqnovva-dev',
  );
  runApp(const CliniqnovvaApp());
}
