import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class RealNamePackage {
  const RealNamePackage({
    required this.id,
    required this.packageKey,
    required this.title,
    required this.priceCoins,
    required this.kind,
  });

  final String id;
  final String packageKey;
  final String title;
  final int priceCoins;
  final String kind;

  factory RealNamePackage.fromMap(Map<String, dynamic> m) {
    return RealNamePackage(
      id: m['id'].toString(),
      packageKey: m['package_key']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      priceCoins: (m['price_coins'] as num?)?.toInt() ?? 0,
      kind: m['kind']?.toString() ?? 'deposit',
    );
  }
}

class RealNameApplication {
  const RealNameApplication({
    required this.id,
    required this.userId,
    required this.status,
    required this.step1Done,
    required this.step2Done,
    required this.step3Done,
    required this.step4Done,
    required this.step5Done,
    this.country,
    this.telephone,
    this.whatsapp,
    this.age,
    this.yearsOfWork,
    this.howKnowApp,
    this.proofExternalAppUrl,
    this.proofWorkAccountUrl,
    this.proofWorkResultsUrl,
    this.legalName,
    this.residentialAddress,
    this.documentNumber,
    this.idPhotoFrontUrl,
    this.idPhotoBackUrl,
    this.videoAuthUrl,
    this.depositPackageId,
    this.depositCoins,
    this.rolePackageId,
    this.rejectReason,
  });

  final String id;
  final String userId;
  final String status;
  final bool step1Done;
  final bool step2Done;
  final bool step3Done;
  final bool step4Done;
  final bool step5Done;
  final String? country;
  final String? telephone;
  final String? whatsapp;
  final int? age;
  final String? yearsOfWork;
  final String? howKnowApp;
  final String? proofExternalAppUrl;
  final String? proofWorkAccountUrl;
  final String? proofWorkResultsUrl;
  final String? legalName;
  final String? residentialAddress;
  final String? documentNumber;
  final String? idPhotoFrontUrl;
  final String? idPhotoBackUrl;
  final String? videoAuthUrl;
  final String? depositPackageId;
  final int? depositCoins;
  final String? rolePackageId;
  final String? rejectReason;

  bool stepDone(int step) {
    switch (step) {
      case 1:
        return step1Done;
      case 2:
        return step2Done;
      case 3:
        return step3Done;
      case 4:
        return step4Done;
      case 5:
        return status == 'approved';
      default:
        return false;
    }
  }

  bool canOpen(int step) {
    return step >= 1 && step <= 5;
  }

  factory RealNameApplication.fromMap(Map<String, dynamic> m) {
    return RealNameApplication(
      id: m['id'].toString(),
      userId: m['user_id'].toString(),
      status: m['status']?.toString() ?? 'draft',
      step1Done: m['step1_done'] == true,
      step2Done: m['step2_done'] == true,
      step3Done: m['step3_done'] == true,
      step4Done: m['step4_done'] == true,
      step5Done: m['step5_done'] == true,
      country: m['country']?.toString(),
      telephone: m['telephone']?.toString(),
      whatsapp: m['whatsapp']?.toString(),
      age: (m['age'] as num?)?.toInt(),
      yearsOfWork: m['years_of_work']?.toString(),
      howKnowApp: m['how_know_app']?.toString(),
      proofExternalAppUrl: m['proof_external_app_url']?.toString(),
      proofWorkAccountUrl: m['proof_work_account_url']?.toString(),
      proofWorkResultsUrl: m['proof_work_results_url']?.toString(),
      legalName: m['legal_name']?.toString(),
      residentialAddress: m['residential_address']?.toString(),
      documentNumber: m['document_number']?.toString(),
      idPhotoFrontUrl: m['id_photo_front_url']?.toString(),
      idPhotoBackUrl: m['id_photo_back_url']?.toString(),
      videoAuthUrl: m['video_auth_url']?.toString(),
      depositPackageId: m['deposit_package_id']?.toString(),
      depositCoins: (m['deposit_coins'] as num?)?.toInt(),
      rolePackageId: m['role_package_id']?.toString(),
      rejectReason: m['reject_reason']?.toString(),
    );
  }
}

class RealNameCenterState {
  const RealNameCenterState({
    required this.application,
    required this.packages,
    required this.shortId,
    required this.coins,
    this.phone,
  });

  final RealNameApplication application;
  final List<RealNamePackage> packages;
  final String shortId;
  final int coins;
  final String? phone;

  List<RealNamePackage> get depositPackages =>
      packages.where((p) => p.kind == 'deposit').toList();

  List<RealNamePackage> get rolePackages =>
      packages.where((p) => p.kind == 'role').toList();
}

final realNameCenterProvider = FutureProvider.autoDispose<RealNameCenterState?>(
  (ref) async {
    ref.watch(authStateProvider);
    final res = await _supabase.rpc('get_my_real_name_application');
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] != true) return null;

    final app = RealNameApplication.fromMap(
      Map<String, dynamic>.from(map['application'] as Map),
    );
    final user = Map<String, dynamic>.from(map['user'] as Map);
    final packages = (map['packages'] as List? ?? [])
        .map(
          (e) => RealNamePackage.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return RealNameCenterState(
      application: app,
      packages: packages,
      shortId: user['short_id']?.toString() ?? '—',
      coins: (user['coins'] as num?)?.toInt() ?? 0,
      phone: user['phone']?.toString(),
    );
  },
);

class RealNameActions {
  static Future<Map<String, dynamic>> upsertStep({
    required String step,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _supabase.rpc(
      'upsert_real_name_step',
      params: {'p_step': step, 'p_payload': payload},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> submitDeposit(String packageId) async {
    final res = await _supabase.rpc(
      'submit_real_name_deposit',
      params: {'p_package_id': packageId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> submitForReview() async {
    final res = await _supabase.rpc('submit_real_name_for_review');
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<String?> uploadKycFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final path =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _supabase.storage
        .from('real_name_kyc')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  static Future<String?> signedKycUrl(
    String? pathOrUrl, {
    int expiresIn = 3600,
  }) async {
    final path = _kycObjectPath(pathOrUrl);
    if (path == null) return null;
    try {
      return await _supabase.storage
          .from('real_name_kyc')
          .createSignedUrl(path, expiresIn);
    } catch (e) {
      debugPrint('[KYC] signed url failed: $e');
      return null;
    }
  }

  static String? _kycObjectPath(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return value.replaceFirst(RegExp(r'^/+'), '');
    }
    const markers = <String>[
      '/storage/v1/object/public/real_name_kyc/',
      '/storage/v1/object/sign/real_name_kyc/',
      '/storage/v1/object/authenticated/real_name_kyc/',
    ];
    for (final marker in markers) {
      final idx = value.indexOf(marker);
      if (idx >= 0) {
        final rest = value.substring(idx + marker.length).split('?').first;
        return Uri.decodeComponent(rest).replaceFirst(RegExp(r'^/+'), '');
      }
    }
    return null;
  }
}
