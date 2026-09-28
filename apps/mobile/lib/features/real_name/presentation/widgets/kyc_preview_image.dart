import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/features/real_name/data/real_name_provider.dart';

class KycPreviewImage extends StatefulWidget {
  const KycPreviewImage({
    super.key,
    required this.pathOrUrl,
    this.fit = BoxFit.cover,
  });

  final String pathOrUrl;
  final BoxFit fit;

  @override
  State<KycPreviewImage> createState() => _KycPreviewImageState();
}

class _KycPreviewImageState extends State<KycPreviewImage> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = RealNameActions.signedKycUrl(widget.pathOrUrl);
  }

  @override
  void didUpdateWidget(covariant KycPreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathOrUrl != widget.pathOrUrl) {
      _future = RealNameActions.signedKycUrl(widget.pathOrUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        final url = snap.data;
        if (url == null || url.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return CachedNetworkImage(imageUrl: url, fit: widget.fit);
      },
    );
  }
}
