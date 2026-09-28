import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseErrorHandler {
  static String handle(dynamic error, {String? customMessage}) {
    String message = customMessage ?? 'An unexpected error occurred';

    debugPrint('--- [DATABASE ERROR LOG] ---');
    if (error is PostgrestException) {
      debugPrint('Type: PostgrestException (Database Query)');
      debugPrint('Message: ${error.message}');
      debugPrint('Code: ${error.code}');
      debugPrint('Details: ${error.details}');
      debugPrint('Hint: ${error.hint}');
      message = 'Database Error: ${error.message}';
    } else if (error is StorageException) {
      debugPrint('Type: StorageException (File Upload/Storage)');
      debugPrint('Message: ${error.message}');
      debugPrint('Error: ${error.error}');
      message = 'Storage Error: ${error.message}';
    } else if (error is AuthException) {
      debugPrint('Type: AuthException (Login/Session)');
      debugPrint('Message: ${error.message}');
      message = 'Auth Error: ${error.message}';
    } else {
      debugPrint('Type: Unknown Error');
      debugPrint('Error: $error');
    }
    debugPrint('---------------------------');

    return message;
  }
}
