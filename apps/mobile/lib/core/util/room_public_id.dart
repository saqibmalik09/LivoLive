String roomPublicId(Map<String, dynamic>? room) {
  if (room == null) return '';

  final sid = room['short_id'];
  if (sid != null && sid.toString().trim().isNotEmpty) {
    return sid.toString();
  }

  final hostSid = room['host_short_id'];
  if (hostSid != null && hostSid.toString().trim().isNotEmpty) {
    return hostSid.toString();
  }

  final host = room['host'];
  if (host is Map) {
    final nested = host['short_id'];
    if (nested != null && nested.toString().trim().isNotEmpty) {
      return nested.toString();
    }
  }

  final id = room['id']?.toString() ?? '';
  if (id.length >= 8) return id.substring(0, 8).toUpperCase();
  return id;
}
