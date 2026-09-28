import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://pbobnvkscssgfpynmdhl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBib2JudmtzY3NzZ2ZweW5tZGhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MTAxNjIsImV4cCI6MjA5ODM4NjE2Mn0.AAwTpGGcr3IPuefqDRZWRCPV5zzDBMFFX7B7qq-a9h0',
  );

  try {
    print(
      '1. Querying live shop_items for ID 2c925a01-0d4a-4c63-ac10-d5c64a68c88e...',
    );
    final List<dynamic> items = await supabase
        .from('shop_items')
        .select('*')
        .eq('id', '2c925a01-0d4a-4c63-ac10-d5c64a68c88e');

    if (items.isEmpty) {
      print('Official Frame NOT FOUND in live database!');
    } else {
      final item = items.first;
      print('Found Item in Live DB:');
      item.forEach((key, val) {
        print('  $key: $val');
      });
    }

    print(
      '\n2. Querying user_inventory for ID 2c925a01-0d4a-4c63-ac10-d5c64a68c88e...',
    );
    final List<dynamic> inventory = await supabase
        .from('user_inventory')
        .select('*')
        .eq('item_id', '2c925a01-0d4a-4c63-ac10-d5c64a68c88e');

    print('Found ${inventory.length} entries in user_inventory.');
    for (var entry in inventory) {
      print(
        '  User ID: ${entry['user_id']} | Equipped: ${entry['is_equipped']} | Expires At: ${entry['expires_at']}',
      );
    }
  } catch (e) {
    print('Error: $e');
  }
}
