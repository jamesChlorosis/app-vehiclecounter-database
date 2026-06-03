class PlateParser {
  static final _loosePlatePattern = RegExp(
    r'([A-Z]{2})([0-9OILSZB]{1,2})([A-Z0-9]{1,2})([0-9OILSZB]{3,4})',
  );
  static final _validPlatePattern = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{3,4}$');

  static String? extract(String rawText) {
    final normalized = rawText.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final match = _loosePlatePattern.firstMatch(normalized);
    if (match == null) return null;
    final plate = [
      match.group(1)!,
      _digits(match.group(2)!),
      _letters(match.group(3)!),
      _digits(match.group(4)!),
    ].join();
    return _validPlatePattern.hasMatch(plate) ? plate : null;
  }

  static String _digits(String value) {
    return value
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('S', '5')
        .replaceAll('Z', '2')
        .replaceAll('B', '8');
  }

  static String _letters(String value) {
    return value
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll('2', 'Z')
        .replaceAll('8', 'B');
  }
}
