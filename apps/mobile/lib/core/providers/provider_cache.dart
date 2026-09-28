import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void cacheFamilyEntry(Ref ref, {Duration ttl = const Duration(minutes: 5)}) {
  final link = ref.keepAlive();
  Timer(ttl, link.close);
}
