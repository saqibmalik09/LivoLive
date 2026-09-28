import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://pbobnvkscssgfpynmdhl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBib2JudmtzY3NzZ2ZweW5tZGhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MTAxNjIsImV4cCI6MjA5ODM4NjE2Mn0.AAwTpGGcr3IPuefqDRZWRCPV5zzDBMFFX7B7qq-a9h0',
  );

  try {
    print('Fetching users from public.users...');
    final List<dynamic> users = await supabase
        .from('users')
        .select('id, username, short_id, avatar_url, banner_url, is_reseller');

    print('Found ${users.length} users:');
    for (var u in users) {
      print(
        'Username: ${u['username']} | UID: ${u['short_id']} | Reseller: ${u['is_reseller']}',
      );
      print('  Avatar: ${u['avatar_url']}');
      print('  Banner: ${u['banner_url']}');

      final avatar = u['avatar_url'] as String?;
      if (avatar != null && avatar.contains('BGz8vO3pK8k')) {
        print(
          '  --> WARNING: User ${u['username']} has invalid Unsplash avatar: $avatar',
        );

        final validAvatar =
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=256&auto=format&fit=crop';
        print('  --> Updating avatar to: $validAvatar');
        await supabase
            .from('users')
            .update({'avatar_url': validAvatar})
            .eq('id', u['id']);
        print('  --> Updated successfully!');
      }

      final banner = u['banner_url'] as String?;
      if (banner != null && banner.contains('BGz8vO3pK8k')) {
        print(
          '  --> WARNING: User ${u['username']} has invalid Unsplash banner: $banner',
        );
        final validBanner =
            'https://images.unsplash.com/photo-1518199266791-5375a83190b7?q=80&w=1000&auto=format&fit=crop';
        print('  --> Updating banner to: $validBanner');
        await supabase
            .from('users')
            .update({'banner_url': validBanner})
            .eq('id', u['id']);
        print('  --> Updated successfully!');
      }
    }

    print('\nFetching rooms from public.rooms...');
    final List<dynamic> rooms = await supabase
        .from('rooms')
        .select('id, title, image_url');
    for (var r in rooms) {
      print('Room: ${r['title']} | Image: ${r['image_url']}');
      final roomImg = r['image_url'] as String?;
      if (roomImg != null && roomImg.contains('BGz8vO3pK8k')) {
        print('  --> WARNING: Room has invalid image: $roomImg');
        final validRoomImg =
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=400&auto=format&fit=crop';
        await supabase
            .from('rooms')
            .update({'image_url': validRoomImg})
            .eq('id', r['id']);
        print('  --> Room image updated successfully!');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
