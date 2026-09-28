import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kTulasiCdnBase =
    'https://game-1305970982.cos.ap-singapore.myqcloud.com';

const String kTulasiSharedRoomId = '0';

String resolveTulasiIconUrl({
  String? iconUrl,
  Map<String, dynamic>? configData,
}) {
  final candidates = <String?>[
    iconUrl,
    configData?['tulasi_banner']?.toString(),
    configData?['tulasi_image_path']?.toString(),
    configData?['tulasi_banner_path']?.toString(),
    if (configData?['image'] != null) configData!['image']?.toString(),
    if (configData?['banner'] != null) configData!['banner']?.toString(),
  ];
  for (final raw in candidates) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) continue;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) return '$kTulasiCdnBase$v';
    if (v.startsWith('upload/')) return '$kTulasiCdnBase/$v';
  }
  return '';
}

bool isTulasiHost(String? host) {
  final h = host?.toLowerCase() ?? '';
  if (h.isEmpty) return false;
  return h == 'tulasigame.com' || h.endsWith('.tulasigame.com');
}

bool isTulasiGameUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return isTulasiHost(uri.host);
}

bool isTulasiGameConfig(Map<String, dynamic>? game) {
  if (game == null) return false;
  final cfg = game['config_data'];
  if (cfg is Map && cfg['provider']?.toString() == 'tulasi') return true;
  final url = game['game_url']?.toString() ?? '';
  return isTulasiGameUrl(url);
}

bool _truthyLandscape(dynamic v) {
  return v == true || v == 1 || v?.toString() == 'true' || v?.toString() == '1';
}

bool isTulasiLandscape(Map<String, dynamic>? game) {
  if (game == null) return false;
  final cfg = game['config_data'];
  final v =
      game['is_landscape'] ??
      game['isLandscape'] ??
      (cfg is Map ? (cfg['isLandscape'] ?? cfg['is_landscape']) : null);
  return _truthyLandscape(v);
}

String tulasiLangCode(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  if (code == 'zh' || code == 'cn') return 'cn';
  return 'en';
}

String tulasiLaunchToken(String sessionToken) {
  var t = sessionToken.trim();
  if (t.startsWith('sklive_')) t = t.substring(7);
  return t;
}

String buildTulasiLaunchUrl(
  String gameUrl, {
  required String token,
  String lang = 'en',
  bool isLandscape = false,
}) {
  final uri = Uri.parse(gameUrl);
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'token': tulasiLaunchToken(token),
          'roomId': kTulasiSharedRoomId,
          'lang': lang,
          'isLandscape': isLandscape ? 'true' : 'false',
        },
      )
      .toString();
}

String? currentSkAccessToken() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null || token.isEmpty) return null;
  return token;
}

const String tulasiPortraitOrientationSpoofJs = r'''
(function () {
  if (window.__skPortraitSpoof) return;
  window.__skPortraitSpoof = true;
  function realSize() {
    var w = window.visualViewport && window.visualViewport.width
      ? window.visualViewport.width
      : (document.documentElement.clientWidth || window.outerWidth || 390);
    var h = window.visualViewport && window.visualViewport.height
      ? window.visualViewport.height
      : (document.documentElement.clientHeight || window.outerHeight || 700);
    return { w: Math.round(w), h: Math.round(h) };
  }
  function portraitH(w, h) {
    return Math.max(h, w + 1);
  }
  try {
    Object.defineProperty(window, 'innerWidth', {
      configurable: true,
      get: function () { return realSize().w; }
    });
    Object.defineProperty(window, 'innerHeight', {
      configurable: true,
      get: function () {
        var s = realSize();
        return portraitH(s.w, s.h);
      }
    });
    Object.defineProperty(document.documentElement, 'clientHeight', {
      configurable: true,
      get: function () {
        var s = realSize();
        return portraitH(s.w, s.h);
      }
    });
  } catch (e) {}
  try {
    Object.defineProperty(screen, 'width', {
      configurable: true,
      get: function () { return realSize().w; }
    });
    Object.defineProperty(screen, 'height', {
      configurable: true,
      get: function () {
        var s = realSize();
        return portraitH(s.w, s.h);
      }
    });
    Object.defineProperty(screen, 'availWidth', {
      configurable: true,
      get: function () { return realSize().w; }
    });
    Object.defineProperty(screen, 'availHeight', {
      configurable: true,
      get: function () {
        var s = realSize();
        return portraitH(s.w, s.h);
      }
    });
  } catch (e) {}
  var origMM = window.matchMedia.bind(window);
  window.matchMedia = function (q) {
    q = String(q || '');
    function fake(matches) {
      return {
        matches: matches,
        media: q,
        onchange: null,
        addListener: function () {},
        removeListener: function () {},
        addEventListener: function () {},
        removeEventListener: function () {},
        dispatchEvent: function () { return false; }
      };
    }
    if (/orientation\s*:\s*landscape/i.test(q)) return fake(false);
    if (/orientation\s*:\s*portrait/i.test(q)) return fake(true);
    return origMM(q);
  };
  try {
    if (screen && screen.orientation) {
      Object.defineProperty(screen.orientation, 'type', {
        configurable: true,
        get: function () { return 'portrait-primary'; }
      });
      Object.defineProperty(screen.orientation, 'angle', {
        configurable: true,
        get: function () { return 0; }
      });
    }
  } catch (e) {}

  function paintBlack() {
    try {
      var css = document.getElementById('sk-tulasi-bg');
      if (!css) {
        css = document.createElement('style');
        css.id = 'sk-tulasi-bg';
        css.textContent =
          'html,body{background:#000!important;margin:0!important;padding:0!important;overflow:hidden!important;}' +
          '#app,#root,canvas,iframe{background:transparent!important;display:block;margin:0!important;}';
        (document.head || document.documentElement).appendChild(css);
      }
      document.documentElement.style.background = '#000';
      if (document.body) {
        document.body.style.background = '#000';
        document.body.style.margin = '0';
        document.body.style.padding = '0';
      }
    } catch (e) {}
  }
  paintBlack();
  document.addEventListener('DOMContentLoaded', paintBlack);
})();
''';

const String tulasiPinGameContentTopJs = r'''
(function () {
  try {
    document.documentElement.style.background = '#000';
    if (document.body) {
      document.body.style.background = '#000';
      document.body.style.margin = '0';
      document.body.style.padding = '0';
      document.body.style.overflow = 'hidden';
      document.body.style.transform = '';
    }
    var nodes = document.querySelectorAll('#app,#root,canvas');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].style.transform = '';
      nodes[i].style.marginTop = '0';
      nodes[i].style.paddingTop = '0';
    }
  } catch (e) {}
})();
''';

String? reattachTulasiLaunchQuery(String navUrl, Uri launchUri) {
  final uri = Uri.tryParse(navUrl);
  if (uri == null || !isTulasiHost(uri.host)) return null;
  if ((uri.queryParameters['token'] ?? '').isNotEmpty) return null;
  final token = launchUri.queryParameters['token'] ?? '';
  if (token.isEmpty) return null;
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'token': token,
          if ((launchUri.queryParameters['merchant'] ?? '').isNotEmpty)
            'merchant': launchUri.queryParameters['merchant']!,
          if ((launchUri.queryParameters['gameId'] ?? '').isNotEmpty)
            'gameId': launchUri.queryParameters['gameId']!,
          'roomId': kTulasiSharedRoomId,
          'lang': launchUri.queryParameters['lang'] ?? 'en',
          'isLandscape': launchUri.queryParameters['isLandscape'] ?? 'false',
        },
      )
      .toString();
}

enum TulasiWebProtocol { none, exit, recharge }

TulasiWebProtocol tulasiProtocolFromUrl(String? url) {
  final u = url?.toLowerCase() ?? '';
  if (u.contains('tulasigame://exit')) return TulasiWebProtocol.exit;
  if (u.contains('tulasigame://recharge')) return TulasiWebProtocol.recharge;
  return TulasiWebProtocol.none;
}
