import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RoomPkSession {
  RoomPkSession({
    required this.id,
    required this.roomId,
    required this.status,
    required this.durationMinutes,
    required this.teamAScore,
    required this.teamBScore,
    required this.endsAt,
    this.sessionType = 'team',
    this.playerAId,
    this.playerBId,
    this.winnerTeam,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String roomId;
  final String status;
  final int durationMinutes;
  final int teamAScore;
  final int teamBScore;
  final DateTime endsAt;
  final String sessionType;
  final String? playerAId;
  final String? playerBId;
  final String? winnerTeam;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';
  bool get isTeam => sessionType == 'team';
  bool get isSolo => sessionType == 'solo';

  Duration get remaining {
    final diff = endsAt.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory RoomPkSession.fromMap(Map<String, dynamic> map) {
    return RoomPkSession(
      id: map['id'].toString(),
      roomId: map['room_id'].toString(),
      status: map['status']?.toString() ?? 'active',
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 5,
      teamAScore: (map['team_a_score'] as num?)?.toInt() ?? 0,
      teamBScore: (map['team_b_score'] as num?)?.toInt() ?? 0,
      endsAt: DateTime.parse(map['ends_at'].toString()).toUtc(),
      sessionType: map['session_type']?.toString() ?? 'team',
      playerAId: map['player_a_id']?.toString(),
      playerBId: map['player_b_id']?.toString(),
      winnerTeam: map['winner_team']?.toString(),
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'].toString()).toUtc()
          : null,
      finishedAt: map['finished_at'] != null
          ? DateTime.parse(map['finished_at'].toString()).toUtc()
          : null,
    );
  }
}

final roomPkSessionProvider = StreamProvider.family<RoomPkSession?, String>((
  ref,
  roomId,
) {
  final controller = StreamController<RoomPkSession?>.broadcast();

  Future<void> load() async {
    try {
      await supabase.rpc('sync_room_pk_session', params: {'p_room_id': roomId});

      final active = await supabase
          .from('room_pk_sessions')
          .select()
          .eq('room_id', roomId)
          .eq('status', 'active')
          .maybeSingle();

      if (!controller.isClosed) {
        if (active != null) {
          controller.add(
            RoomPkSession.fromMap(Map<String, dynamic>.from(active)),
          );
          return;
        }

        final recent = await supabase
            .from('room_pk_sessions')
            .select()
            .eq('room_id', roomId)
            .eq('status', 'finished')
            .order('finished_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (recent != null &&
            recent['finished_at'] != null &&
            DateTime.now()
                    .difference(
                      DateTime.parse(recent['finished_at'].toString()),
                    )
                    .inSeconds <
                12) {
          controller.add(
            RoomPkSession.fromMap(Map<String, dynamic>.from(recent)),
          );
        } else {
          controller.add(null);
        }
      }
    } catch (_) {
      if (!controller.isClosed) controller.add(null);
    }
  }

  final channel = supabase.channel('room_pk_$roomId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_pk_sessions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) => load(),
      )
      .subscribe();

  load();
  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

final roomPkContributionsProvider =
    StreamProvider.family<Map<String, int>, String>((ref, sessionId) {
      final controller = StreamController<Map<String, int>>.broadcast();

      Future<void> load() async {
        try {
          final response = await supabase
              .from('room_pk_gift_contributions')
              .select('receiver_id, amount')
              .eq('session_id', sessionId);

          final totals = <String, int>{};
          for (final row in response as List) {
            final id = row['receiver_id']?.toString();
            if (id == null) continue;
            totals[id] =
                (totals[id] ?? 0) + ((row['amount'] as num?)?.toInt() ?? 0);
          }
          if (!controller.isClosed) controller.add(totals);
        } catch (_) {
          if (!controller.isClosed) controller.add({});
        }
      }

      final channel = supabase.channel('room_pk_contrib_$sessionId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_pk_gift_contributions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: sessionId,
            ),
            callback: (_) => load(),
          )
          .subscribe();

      load();
      ref.onDispose(() {
        supabase.removeChannel(channel);
        controller.close();
      });

      return controller.stream;
    });

class TeamPkService {
  static Future<Map<String, dynamic>> startSession({
    required String roomId,
    required int durationMinutes,
  }) async {
    final response = await supabase.rpc(
      'start_room_pk_session',
      params: {'p_room_id': roomId, 'p_duration_minutes': durationMinutes},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> startSoloSession({
    required String roomId,
    required int durationMinutes,
  }) async {
    final response = await supabase.rpc(
      'start_room_solo_pk_session',
      params: {'p_room_id': roomId, 'p_duration_minutes': durationMinutes},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> stopSession(String sessionId) async {
    final response = await supabase.rpc(
      'stop_room_pk_session',
      params: {'p_session_id': sessionId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<void> syncSession(String roomId) async {
    await supabase.rpc('sync_room_pk_session', params: {'p_room_id': roomId});
  }
}

String? teamForSeatIndex(int index) {
  if (index < 0 || index >= 10) return null;
  return index < 5 ? 'a' : 'b';
}
