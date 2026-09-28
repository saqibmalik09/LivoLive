import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class RoomChatImageService {
  RoomChatImageService._();

  static const String uploadFolder = 'rooms/images';

  static Future<XFile?> pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      return await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
    } catch (e) {
      debugPrint('[RoomChatImage] pick failed: $e');
      return null;
    }
  }

  static Future<String?> saveToGallery(String url) async {
    try {
      if (url.startsWith('/')) {
        await Gal.putImage(url, album: 'LIVO');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'sk_live_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempPath = '${tempDir.path}/$fileName';

      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) {
          return 'Download failed (${response.statusCode})';
        }
        final bytes = await consolidateHttpClientResponseBytes(response);
        await File(tempPath).writeAsBytes(bytes, flush: true);
      } finally {
        client.close(force: true);
      }

      await Gal.putImage(tempPath, album: 'LIVO');
      return null;
    } on GalException catch (e) {
      debugPrint('[RoomChatImage] gal error: ${e.type}');
      return e.type == GalExceptionType.accessDenied
          ? 'Gallery permission denied'
          : 'Could not save photo';
    } catch (e) {
      debugPrint('[RoomChatImage] save failed: $e');
      return 'Could not save photo';
    }
  }
}
