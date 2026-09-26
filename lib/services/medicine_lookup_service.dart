import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/medicine_suggestion.dart';

/// Looks up real medicine names, strengths and dosage forms from the
/// openFDA drug database (api.fda.gov) — free, no API key needed for
/// normal use. Covers US-market brand and generic drug names; it won't
/// know every medicine, especially ones only sold outside the US.
///
/// Needs an internet connection. Any network failure is treated as "no
/// suggestions" rather than an error, so the name field always still works
/// as a plain text box.
class MedicineLookupService {
  static const _baseUrl = 'https://api.fda.gov/drug/ndc.json';

  Future<List<MedicineSuggestion>> search(String query, {int limit = 8}) async {
    final term = query.trim();
    if (term.length < 2) return const [];

    final escaped = term.replaceAll('"', '');
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'search': '(generic_name:$escaped* OR brand_name:$escaped*)',
      'limit': '$limit',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List? ?? const [];

      final seen = <String>{};
      final suggestions = <MedicineSuggestion>[];
      for (final raw in results) {
        final item = raw as Map<String, dynamic>;
        final suggestion = _parse(item);
        if (suggestion == null) continue;
        // The same drug name can repeat across several package listings;
        // keep only the first (name + strength) we see.
        final key = '${suggestion.name.toLowerCase()}|${suggestion.strength}';
        if (!seen.add(key)) continue;
        suggestions.add(suggestion);
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  MedicineSuggestion? _parse(Map<String, dynamic> item) {
    final brand = (item['brand_name'] as String? ?? '').trim();
    final generic = (item['generic_name'] as String? ?? '').trim();
    final name = brand.isNotEmpty ? brand : generic;
    if (name.isEmpty) return null;

    final dosageForm = (item['dosage_form'] as String? ?? '').trim();
    final ingredients = item['active_ingredients'] as List? ?? const [];
    final strength = ingredients.isNotEmpty
        ? _cleanStrength((ingredients.first as Map<String, dynamic>)['strength'] as String? ?? '')
        : '';

    return MedicineSuggestion(
      name: _titleCase(name),
      strength: strength,
      dosageForm: _titleCase(dosageForm),
      unit: _guessUnit(dosageForm),
    );
  }

  /// openFDA strengths look like "500 mg/1" (per one unit) — drop the "/1".
  String _cleanStrength(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'/1$'), '');
    return s.trim();
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _guessUnit(String dosageFormUpper) {
    final f = dosageFormUpper.toUpperCase();
    if (f.contains('TABLET')) return 'tablet';
    if (f.contains('CAPSULE')) return 'capsule';
    if (f.contains('PATCH')) return 'patch';
    if (f.contains('DROP')) return 'drop';
    if (f.contains('SPRAY') || f.contains('INHAL') || f.contains('AEROSOL')) return 'puff';
    if (f.contains('POWDER') || f.contains('GRANULE') || f.contains('PACKET')) return 'sachet';
    if (f.contains('SOLUTION') ||
        f.contains('SYRUP') ||
        f.contains('SUSPENSION') ||
        f.contains('LIQUID') ||
        f.contains('ELIXIR')) {
      return 'ml';
    }
    return Units.all.contains('unit') ? 'unit' : Units.all.first;
  }
}