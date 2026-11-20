void sortRoomsByPopularRanking(List<Map<String, dynamic>> rooms) {
  rooms.sort((a, b) {
    final aSeated = _seatedCount(a);
    final bSeated = _seatedCount(b);
    if (aSeated != bSeated) {
      return bSeated.compareTo(aSeated);
    }

    final aUsers = (a['online_users_count'] as num?)?.toInt() ?? 0;
    final bUsers = (b['online_users_count'] as num?)?.toInt() ?? 0;
    if (aUsers != bUsers) {
      return bUsers.compareTo(aUsers);
    }

    final aScore = (a['ranking_score'] as num?)?.toInt() ?? 0;
    final bScore = (b['ranking_score'] as num?)?.toInt() ?? 0;
    if (aScore != bScore) {
      return bScore.compareTo(aScore);
    }

    // Must match the query's final keys, or this re-sort reshuffles each page
    // against the server's order and rooms jump as more pages load.
    final byCreated = _createdAt(b).compareTo(_createdAt(a));
    if (byCreated != 0) return byCreated;
    return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
  });
}

DateTime _createdAt(Map<String, dynamic> room) {
  return DateTime.tryParse(room['created_at']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

int _seatedCount(Map<String, dynamic> room) {
  final seated = (room['seated_users_count'] as num?)?.toInt();
  if (seated != null) return seated;
  final avatars = room['top_avatars'];
  if (avatars is List) return avatars.length;
  return 0;
}

void sortRoomsByNewest(List<Map<String, dynamic>> rooms) {
  rooms.sort((a, b) {
    final aTime =
        DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
    final bTime =
        DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
    return bTime.compareTo(aTime);
  });
}
