class Units {
  static const all = <String>[
    'tablet',
    'capsule',
    'ml',
    'drop',
    'puff',
    'patch',
    'sachet',
    'unit',
  ];

  /// "1 tablet", "2 tablets", "5 ml".
  static String label(String unit, double amount) {
    if (unit == 'ml' || amount == 1) return unit;
    return '${unit}s';
  }
}
