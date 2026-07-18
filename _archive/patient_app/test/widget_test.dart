import 'package:flutter_test/flutter_test.dart';

import 'package:patient_app/app.dart';
import 'package:patient_app/core/config/flavor_config.dart';

void main() {
  testWidgets('App boots and shows the setup placeholder screen', (WidgetTester tester) async {
    FlavorConfig(
      flavor: Flavor.dev,
      apiBaseUrl: 'https://api-dev.cliniqnovva.rw',
      firebaseProjectId: 'cliniqnovva-dev',
    );

    await tester.pumpWidget(const CliniqnovvaApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Project setup complete'), findsOneWidget);
  });
}
