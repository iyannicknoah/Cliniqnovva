/// Rwanda's administrative divisions — the 5 provinces and their 30
/// districts, for the branch form's cascading Province → District dropdowns
/// (Part 6 Task 1/4). Sectors/cells/villages are free-text fields, not
/// dropdowns: there are 416 sectors and thousands of cells/villages, far too
/// many to hardcode usefully.
abstract final class RwandaLocations {
  static const Map<String, List<String>> districtsByProvince = {
    'Kigali City': ['Gasabo', 'Kicukiro', 'Nyarugenge'],
    'Northern Province': ['Burera', 'Gakenke', 'Gicumbi', 'Musanze', 'Rulindo'],
    'Southern Province': [
      'Gisagara',
      'Huye',
      'Kamonyi',
      'Muhanga',
      'Nyamagabe',
      'Nyanza',
      'Nyaruguru',
      'Ruhango',
    ],
    'Eastern Province': [
      'Bugesera',
      'Gatsibo',
      'Kayonza',
      'Kirehe',
      'Ngoma',
      'Nyagatare',
      'Rwamagana',
    ],
    'Western Province': [
      'Karongi',
      'Ngororero',
      'Nyabihu',
      'Nyamasheke',
      'Rubavu',
      'Rusizi',
      'Rutsiro',
    ],
  };

  static List<String> get provinces => districtsByProvince.keys.toList();

  static List<String> districtsOf(String? province) =>
      districtsByProvince[province] ?? const [];
}
