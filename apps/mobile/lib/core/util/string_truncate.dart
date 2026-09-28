import 'package:characters/characters.dart';

String truncateGraphemes(String s, int maxChars) {
  if (maxChars <= 0) return '';
  final chars = s.characters;
  if (chars.length <= maxChars) return s;
  return '${chars.take(maxChars)}…';
}
