bool isUserSearchQueryReady(String query) {
  final t = query.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'^\d+$').hasMatch(t)) return true;
  return t.length >= 2;
}

bool isNumericUidQuery(String query) => RegExp(r'^\d+$').hasMatch(query.trim());
