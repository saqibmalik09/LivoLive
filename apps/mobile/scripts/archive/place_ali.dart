import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://pbobnvkscssgfpynmdhl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBib2JudmtzY3NzZ2ZweW5tZGhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MTAxNjIsImV4cCI6MjA5ODM4NjE2Mn0.AAwTpGGcr3IPuefqDRZWRCPV5zzDBMFFX7B7qq-a9h0',
  );

  try {
    final roomData = await supabase
        .from('rooms')
        .select('id, title')
        .ilike('title', '%mohsin%royal%lounge%')
        .maybeSingle();

    if (roomData == null) {
      print('Room not found');
      exit(1);
    }
    print(
      'Found Room: ' +
          roomData['title'].toString() +
          ' ' +
          roomData['id'].toString(),
    );

    final aliData = await supabase
        .from('users')
        .select('id, username')
        .ilike('username', '%ali%')
        .maybeSingle();

    if (aliData == null) {
      print('User ali not found');
      exit(1);
    }
    print(
      'Found User: ' +
          aliData['username'].toString() +
          ' ' +
          aliData['id'].toString(),
    );

    await supabase.from('room_seats').upsert({
      'room_id': roomData['id'],
      'user_id': aliData['id'],
      'seat_index': 1,
      'is_muted': false,
      'is_locked': false,
    }, onConflict: 'room_id,user_id');

    print('Successfully placed Ali on the mic!');
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
