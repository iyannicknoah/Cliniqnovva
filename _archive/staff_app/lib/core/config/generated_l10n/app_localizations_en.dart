// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cliniqnovva Staff';

  @override
  String get login => 'Log in';

  @override
  String get schedule => 'Schedule';

  @override
  String get myPatients => 'My patients';

  @override
  String get recordVitals => 'Record vitals';

  @override
  String get addDiagnosis => 'Add diagnosis';

  @override
  String get addPrescription => 'Add prescription';

  @override
  String get markComplete => 'Mark complete';

  @override
  String get checkIn => 'Check in';

  @override
  String get queue => 'Queue';

  @override
  String get selectLanguage => 'Select language';
}
