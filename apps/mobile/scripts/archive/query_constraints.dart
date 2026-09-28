import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://pbobnvkscssgfpynmdhl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBib2JudmtzY3NzZ2ZweW5tZGhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MTAxNjIsImV4cCI6MjA5ODM4NjE2Mn0.AAwTpGGcr3IPuefqDRZWRCPV5zzDBMFFX7B7qq-a9h0',
  );

  try {
    print('Querying constraints on transactions table...');
    final List<dynamic> constraints = await supabase.rpc(
      'get_constraints_info',
      params: {},
    );
    print(constraints);
  } catch (e) {
    print('Failed to call RPC get_constraints_info: $e');
    print(
      'Let us query information_schema.table_constraints via postgrest if allowed...',
    );
    try {
      final response = await supabase
          .from('transactions')
          .select('amount')
          .limit(1);
      print('Direct select amount from transactions works: $response');
    } catch (err) {
      print('Error: $err');
    }
  }
}
