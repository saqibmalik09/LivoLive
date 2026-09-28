String displayUserId(Map<String, dynamic>? user, {String fallback = '—'}) {
  if (user == null) return fallback;
  final shortId = user['short_id']?.toString().trim();
  if (shortId != null && shortId.isNotEmpty) return shortId;
  final id = user['id']?.toString();
  if (id != null && id.length >= 8) return id.substring(0, 8).toUpperCase();
  return fallback;
}
