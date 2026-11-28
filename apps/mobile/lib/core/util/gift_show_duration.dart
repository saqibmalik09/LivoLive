/// How long each gift holds in the centre of the room before it flies to the
/// receivers, as set per gift on the dashboard ("Show for (seconds)").
///
/// Keyed by the gift's media URLs because every send path (gift sheet, repeat
/// button, chat sheet, socket echo, postgres insert) already carries those,
/// while only some of them carry the gift id.
class GiftShowDuration {
  GiftShowDuration._();

  static const int defaultMs = 5000;

  /// Used when a gift is set to 0 ("the animation's own length") but has no
  /// SVGA to take a length from.
  static const int stillImageMs = 3000;

  static const int maxMs = 60000;
  static const int _maxEntries = 500;

  static final Map<String, int> _byMedia = <String, int>{};

  static void remember({String? svgaUrl, String? iconUrl, Object? ms}) {
    if (ms is! num) return;
    final value = ms.toInt().clamp(0, maxMs);
    for (final raw in [svgaUrl, iconUrl]) {
      final key = raw?.trim() ?? '';
      if (key.isEmpty) continue;
      _byMedia.remove(key);
      _byMedia[key] = value;
    }
    while (_byMedia.length > _maxEntries) {
      _byMedia.remove(_byMedia.keys.first);
    }
  }

  /// The configured hold in ms; 0 means the animation's own length. Gifts
  /// nobody configured get [defaultMs].
  static int lookup({String svgaUrl = '', String iconUrl = ''}) {
    final svga = svgaUrl.trim();
    if (svga.isNotEmpty) {
      final hit = _byMedia[svga];
      if (hit != null) return hit;
    }
    final icon = iconUrl.trim();
    if (icon.isNotEmpty) {
      final hit = _byMedia[icon];
      if (hit != null) return hit;
    }
    return defaultMs;
  }
}
