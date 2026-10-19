List<String> extractMentions(String text) {
  final matches = RegExp(r'@([^\s@]+)').allMatches(text);
  return matches
      .map((match) => match.group(1)?.trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toList();
}
