import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomShareLinkService {
  RoomShareLinkService._();

  static const String bucket = 'deep_links';
  static const String objectPath = 'room.html';
  static bool _uploadSucceeded = false;

  static Future<bool> ensureSharePageUploaded() async {
    if (_uploadSucceeded) return true;

    try {
      final supabase = Supabase.instance.client;
      final bytes = (await rootBundle.load(
        'assets/deep_links/room.html',
      )).buffer.asUint8List();

      await supabase.storage
          .from(bucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'text/html',
            ),
          );
      debugPrint('Room share page uploaded to $bucket/$objectPath');
      _uploadSucceeded = true;
      return true;
    } catch (e, stack) {
      debugPrint('Room share page upload failed: $e\n$stack');
      return false;
    }
  }
}
