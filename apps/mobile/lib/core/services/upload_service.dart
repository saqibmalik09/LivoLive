import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/dev_log.dart';

enum UploadCropAspect { square, landscape16x9, portrait9x16 }

class UploadService {
  UploadService._();
  static final instance = UploadService._();

  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  Future<String?> pickAndUploadAgencyLogo(BuildContext context) {
    return _pickCropAndUpload(
      context: context,
      cropAspect: UploadCropAspect.square,
      bucket: 'profiles',
      pathPrefix: 'agency_logos/',
      updateUser: false,
      cropTitle: 'Crop agency logo',
    );
  }

  Future<String?> pickAndUploadImage({
    required bool isAvatar,
    required BuildContext context,
  }) async {
    return _pickCropAndUpload(
      context: context,
      cropAspect: isAvatar
          ? UploadCropAspect.square
          : UploadCropAspect.landscape16x9,
      bucket: 'profiles',
      updateUser: true,
      profileIsAvatar: isAvatar,
    );
  }

  Future<String?> pickAndUploadCoverPhoto(BuildContext context) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final row = await _supabase
          .from('users')
          .select('cover_images')
          .eq('id', user.id)
          .maybeSingle();
      final existing = _parseCoverImages(row?['cover_images']);
      if (existing.length >= 3) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 3 cover photos allowed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      final publicUrl = await _pickCropAndUpload(
        context: context,
        cropAspect: UploadCropAspect.square,
        bucket: 'profiles',
        pathPrefix: 'covers/',
        updateUser: false,
        cropTitle: 'Crop cover photo',
      );
      if (publicUrl == null) return null;

      final updated = [...existing, publicUrl];
      await _supabase
          .from('users')
          .update({'cover_images': updated})
          .eq('id', user.id);

      return publicUrl;
    } catch (e) {
      debugPrint('COVER_UPLOAD_ERROR: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> removeCoverPhoto(String url) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final row = await _supabase
        .from('users')
        .select('cover_images')
        .eq('id', user.id)
        .maybeSingle();
    final existing = _parseCoverImages(row?['cover_images']);
    final updated = existing.where((u) => u != url).toList();
    await _supabase
        .from('users')
        .update({'cover_images': updated})
        .eq('id', user.id);
  }

  List<String> _parseCoverImages(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<String?> pickRoomCover(BuildContext context) async {
    return _pickCropAndUpload(
      context: context,
      cropAspect: UploadCropAspect.square,
      bucket: 'profiles',
      pathPrefix: 'rooms/',
      updateUser: false,
    );
  }

  Future<String?> pickRoomBackground(BuildContext context) async {
    final type = await _showRoomBackgroundTypePicker(context);
    if (type == null) return null;
    if (type == _RoomBackgroundUploadType.svga) {
      return _pickAndUploadSvga(context);
    }
    return _pickCropAndUpload(
      context: context,
      cropAspect: UploadCropAspect.portrait9x16,
      bucket: 'room_backgrounds',
      pathPrefix: '',
      updateUser: false,
      cropTitle: 'Crop room background (9:16)',
    );
  }

  Future<String?> _pickAndUploadSvga(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svga'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null || path.isEmpty) return null;

      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final file = File(path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.svga';
      final filePath = '${user.id}/$fileName';

      await _supabase.storage
          .from('room_backgrounds')
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );

      return _supabase.storage.from('room_backgrounds').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('UPLOAD_SVGA_ERROR: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SVGA upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<String?> pickSupportScreenshot(BuildContext context) async {
    return _pickCropAndUpload(
      context: context,
      cropAspect: UploadCropAspect.landscape16x9,
      bucket: 'support_attachments',
      pathPrefix: 'support/',
      updateUser: false,
    );
  }

  Future<String?> _pickCropAndUpload({
    required BuildContext context,
    required UploadCropAspect cropAspect,
    required String bucket,
    String pathPrefix = '',
    required bool updateUser,
    bool profileIsAvatar = true,
    String cropTitle = 'Crop Image',
  }) async {
    try {
      final source = await _showSourcePicker(context);
      if (source == null) return null;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final CropAspectRatio aspectRatio;
      final CropAspectRatioPreset initPreset;
      switch (cropAspect) {
        case UploadCropAspect.square:
          aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1);
          initPreset = CropAspectRatioPreset.square;
        case UploadCropAspect.landscape16x9:
          aspectRatio = const CropAspectRatio(ratioX: 16, ratioY: 9);
          initPreset = CropAspectRatioPreset.ratio16x9;
        case UploadCropAspect.portrait9x16:
          aspectRatio = const CropAspectRatio(ratioX: 9, ratioY: 16);
          initPreset = CropAspectRatioPreset.original;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: cropTitle,
            toolbarColor: AppColors.primary,
            statusBarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: initPreset,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: cropTitle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return null;

      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final file = File(croppedFile.path);
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final filePath = '${user.id}/$pathPrefix$fileName';

      await _supabase.storage
          .from(bucket)
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(filePath);
      devLog('--- [DEBUG] Uploaded to Storage, Public URL: $publicUrl');

      if (updateUser) {
        final updateData = profileIsAvatar
            ? {'avatar_url': publicUrl}
            : {'banner_url': publicUrl};
        await _supabase.from('users').update(updateData).eq('id', user.id);
      }

      return publicUrl;
    } catch (e) {
      debugPrint('UPLOAD_SERVICE_ERROR: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<_RoomBackgroundUploadType?> _showRoomBackgroundTypePicker(
    BuildContext context,
  ) async {
    return showModalBottomSheet<_RoomBackgroundUploadType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Room Background',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Iconsax.gallery),
                title: const Text('Photo (9:16 crop)'),
                subtitle: const Text('JPEG, PNG, WebP'),
                onTap: () =>
                    Navigator.pop(context, _RoomBackgroundUploadType.image),
              ),
              ListTile(
                leading: const Icon(Iconsax.video_play),
                title: const Text('SVGA animation'),
                subtitle: const Text('.svga file from device'),
                onTap: () =>
                    Navigator.pop(context, _RoomBackgroundUploadType.svga),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<ImageSource?> _showSourcePicker(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Iconsax.camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Iconsax.gallery),
                title: const Text('Upload from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RoomBackgroundUploadType { image, svga }
