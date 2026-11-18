class NameNormalizer {
  const NameNormalizer._();

  static String normalize(String value) {
    final output = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      if (_isIgnored(rune)) continue;

      final normalized = switch (rune) {
        0x0643 => 0x06A9, // Arabic kaf -> Persian kaf
        0x064A || 0x0649 => 0x06CC, // Arabic yeh/alef maksura -> Persian yeh
        0x0622 || 0x0623 || 0x0625 => 0x0627, // Alif variants -> alif
        0x0624 => 0x0648, // Waw with hamza -> waw
        0x0626 => 0x06CC, // Yeh with hamza -> Persian yeh
        >= 0x0660 && <= 0x0669 => rune - 0x0660 + 0x30,
        >= 0x06F0 && <= 0x06F9 => rune - 0x06F0 + 0x30,
        _ => rune,
      };
      output.writeCharCode(normalized);
    }

    return output.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isIgnored(int rune) =>
      rune == 0x0640 || // Tatweel
      (rune >= 0x064B && rune <= 0x065F) || // Arabic vowel marks
      rune == 0x0670 ||
      rune == 0x200C || // ZWNJ
      rune == 0x200D || // ZWJ
      rune == 0x200E ||
      rune == 0x200F ||
      (rune >= 0x202A && rune <= 0x202E) ||
      rune == 0xFEFF;

  static List<String> suggestions(
    String query,
    Iterable<String> candidates, {
    int limit = 5,
  }) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty || limit <= 0) return const [];

    final maximumDistance = normalizedQuery.runes.length < 5 ? 1 : 2;
    final ranked = <({String value, int distance})>[];
    final seen = <String>{};

    for (final candidate in candidates) {
      final normalizedCandidate = normalize(candidate);
      if (normalizedCandidate.isEmpty || !seen.add(normalizedCandidate)) {
        continue;
      }
      if (normalizedCandidate.contains(normalizedQuery)) {
        ranked.add((value: candidate, distance: 0));
        continue;
      }

      final distance = _editDistance(
        normalizedQuery.runes.toList(growable: false),
        normalizedCandidate.runes.toList(growable: false),
        maximumDistance,
      );
      if (distance <= maximumDistance) {
        ranked.add((value: candidate, distance: distance));
      }
    }

    ranked.sort((a, b) => a.distance.compareTo(b.distance));
    return ranked.take(limit).map((entry) => entry.value).toList();
  }

  static int _editDistance(List<int> a, List<int> b, int cutoff) {
    if ((a.length - b.length).abs() > cutoff) return cutoff + 1;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, cutoff + 1);
      current[0] = i;
      var rowMinimum = current[0];
      for (var j = 1; j <= b.length; j++) {
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
        if (current[j] < rowMinimum) rowMinimum = current[j];
      }
      if (rowMinimum > cutoff) return cutoff + 1;
      previous = current;
    }
    return previous[b.length];
  }
}
