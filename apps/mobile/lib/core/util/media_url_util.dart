class SupabaseImageTransform {
  SupabaseImageTransform._();

  static const _objectPath = '/storage/v1/object/public/';
  static const _renderPath = '/storage/v1/render/image/public/';

  static const _legacyStorageHosts = <String, String>{
    'sklive.sin.baas.zuvodev.com': 'api.skliveparty.online',
    'pbobnvkscssgfpynmdhl.supabase.co': 'api.skliveparty.online',
    'supabasekong-mnq3vesx0syflb0m0bot3oa2.51.222.81.97.sslip.io':
        'api.skliveparty.online',
  };

  static String rewriteStorageHost(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      final replacement = _legacyStorageHosts[host];
      if (replacement == null) return trimmed;
      return uri.replace(host: replacement, scheme: 'https').toString();
    } catch (_) {
      return trimmed;
    }
  }

  static String? url(
    String? url, {
    int width = 600,
    int? height,
    String resize = 'cover',
    int quality = 85,
  }) {
    if (url == null || url.trim().isEmpty) return url;
    final trimmed = rewriteStorageHost(url.trim());

    if (trimmed.startsWith('data:') ||
        trimmed.toLowerCase().endsWith('.svga')) {
      return trimmed;
    }

    final idx = trimmed.indexOf(_objectPath);
    if (idx == -1) return trimmed;

    final base = trimmed.substring(0, idx);
    final rest = trimmed.substring(idx + _objectPath.length);

    final qMark = rest.indexOf('?');
    final pathOnly = qMark == -1 ? rest : rest.substring(0, qMark);

    final params = StringBuffer('?width=$width&quality=$quality&format=webp');
    if (height != null) {
      params.write('&height=$height&resize=$resize');
    }

    return '$base$_renderPath$pathOnly$params';
  }
}

class MediaUrlUtil {
  MediaUrlUtil._();

  static String? nullableMediaUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return SupabaseImageTransform.rewriteStorageHost(trimmed);
  }

  static bool isSvgaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    try {
      final path = Uri.parse(url.trim()).path.toLowerCase();
      return path.endsWith('.svga');
    } catch (_) {
      return url.trim().toLowerCase().contains('.svga');
    }
  }

  static ({String? imageUrl, String? svgaUrl}) resolveEntrancePatti({
    String? imageUrl,
    String? svgaUrl,
  }) {
    final rawImage = nullableMediaUrl(imageUrl);
    final rawSvga = nullableMediaUrl(svgaUrl);
    if (isSvgaUrl(rawSvga)) {
      return (imageUrl: null, svgaUrl: rawSvga);
    }
    if (isSvgaUrl(rawImage)) {
      return (imageUrl: null, svgaUrl: rawImage);
    }
    return (imageUrl: rawImage ?? rawSvga, svgaUrl: null);
  }
}
