/// One autocomplete result from the drug lookup API, already mapped onto
/// this app's own fields (name, strength, unit).
class MedicineSuggestion {
  const MedicineSuggestion({
    required this.name,
    required this.strength,
    required this.dosageForm,
    required this.unit,
  });

  final String name;

  /// e.g. "500 mg". Empty if the source data didn't have a clean strength.
  final String strength;

  /// Raw dosage form from the API, e.g. "TABLET, FILM COATED" — shown to
  /// the user as extra context in the suggestion list.
  final String dosageForm;

  /// This app's own unit (see core/constants.dart Units.all), guessed from
  /// [dosageForm]. Always a valid entry in Units.all.
  final String unit;
}