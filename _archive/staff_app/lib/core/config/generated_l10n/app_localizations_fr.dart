// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Cliniqnovva Personnel';

  @override
  String get login => 'Connexion';

  @override
  String get schedule => 'Planning';

  @override
  String get myPatients => 'Mes patients';

  @override
  String get recordVitals => 'Enregistrer les constantes';

  @override
  String get addDiagnosis => 'Ajouter un diagnostic';

  @override
  String get addPrescription => 'Ajouter une ordonnance';

  @override
  String get markComplete => 'Marquer comme terminé';

  @override
  String get checkIn => 'Enregistrer l\'arrivée';

  @override
  String get queue => 'File d\'attente';

  @override
  String get selectLanguage => 'Choisir la langue';
}
