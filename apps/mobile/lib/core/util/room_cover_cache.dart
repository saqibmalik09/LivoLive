import 'package:flutter/widgets.dart';

int roomCoverCacheWidth([BuildContext? context]) {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final dpr = views.isEmpty ? 2.0 : views.first.devicePixelRatio;
  double logicalCardW;
  if (context != null) {
    logicalCardW = (MediaQuery.sizeOf(context).width - 16 - 12) / 2;
  } else if (views.isEmpty) {
    logicalCardW = 180.0;
  } else {
    logicalCardW = views.first.physicalSize.width / dpr / 2;
  }
  return (logicalCardW * dpr).round().clamp(200, 480);
}
