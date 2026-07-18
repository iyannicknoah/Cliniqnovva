import 'package:flutter/material.dart';

import 'core/config/flavor_config.dart';
import 'app.dart';

// TODO(Phase 1): call Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// here once `flutterfire configure` has been run against the cliniqnovva-prod project
// and firebase_options_prod.dart exists.
void main() {
  FlavorConfig(
    flavor: Flavor.prod,
    apiBaseUrl: 'https://api.cliniqnovva.rw',
    firebaseProjectId: 'cliniqnovva-prod',
  );
  runApp(const CliniqnovvaApp());
}
