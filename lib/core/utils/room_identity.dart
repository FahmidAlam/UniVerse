/// Physical identity comparison. Aliases/usage belong to the selected run's
/// verified room configuration; no semester-specific purpose is a default.
abstract class RoomIdentity {
  // User-confirmed current physical identity, not a room-purpose restriction.
  static String currentKey(String label) =>
      key(label, aliases: const {'PHY LAB': 'RAB-106'});
  static String key(String label, {Map<String, String> aliases = const {}}) {
    String normalize(String text) =>
        text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final mapping = {
      for (final e in aliases.entries) normalize(e.key): normalize(e.value)
    };
    var result = normalize(label);
    final seen = <String>{};
    while (mapping.containsKey(result) && mapping[result] != result) {
      if (!seen.add(result)) throw const FormatException('Cyclic room aliases');
      result = mapping[result]!;
    }
    return result;
  }
}
