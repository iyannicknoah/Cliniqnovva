// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Cliniqnovva';

  @override
  String get login => 'Connexion';

  @override
  String get searchClinics => 'Rechercher une clinique';

  @override
  String get bookAppointment => 'Prendre rendez-vous';

  @override
  String get myAppointments => 'Mes rendez-vous';

  @override
  String get medicalHistory => 'Antécédents médicaux';

  @override
  String get invoicesAndReceipts => 'Factures et reçus';

  @override
  String get chatWithClinic => 'Discuter avec la clinique';

  @override
  String get leaveReview => 'Laisser un avis';

  @override
  String get reschedule => 'Reprogrammer';

  @override
  String get cancelAppointment => 'Annuler le rendez-vous';

  @override
  String get selectLanguage => 'Choisir la langue';
}
