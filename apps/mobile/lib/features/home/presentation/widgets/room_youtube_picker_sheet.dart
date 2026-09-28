import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:sk_live/features/home/services/room_youtube_util.dart';

class RoomYoutubePickerSheet extends StatefulWidget {
  final bool isPartyActive;
  final void Function(String videoId) onPlayVideo;
  final VoidCallback onStopParty;

  const RoomYoutubePickerSheet({
    super.key,
    required this.isPartyActive,
    required this.onPlayVideo,
    required this.onStopParty,
  });

  @override
  State<RoomYoutubePickerSheet> createState() => _RoomYoutubePickerSheetState();
}

class _RoomYoutubePickerSheetState extends State<RoomYoutubePickerSheet> {
  final _searchController = TextEditingController();
  final _urlController = TextEditingController();
  final _yt = YoutubeExplode();

  Timer? _debounce;
  bool _searching = false;
  String? _searchError;
  List<Video> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _urlController.dispose();
    _yt.close();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _searchError = null;
        _searching = false;
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final list = await _yt.search.search(query);
      if (!mounted) return;
      setState(() {
        _results = list.toList().take(20).toList();
        _searching = false;
        if (_results.isEmpty) {
          _searchError = 'No videos found';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = 'Search failed. Try paste URL below.';
        _results = [];
      });
    }
  }

  void _playFromUrl() {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;
    final videoId = parseYoutubeVideoId(input) ?? input;
    if (!isValidYoutubeVideoId(videoId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid YouTube URL or video ID'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    widget.onPlayVideo(videoId);
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: maxH,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'YouTube Watch Party',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (widget.isPartyActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onStopParty,
                  icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                  label: const Text(
                    'Stop current video',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search videos on YouTube…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Iconsax.search_normal,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (v) {
                if (v.trim().length >= 2) _runSearch(v.trim());
              },
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchError != null && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _searchError!,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else if (_searchController.text.trim().length < 2)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Type to search — same as YouTube',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final video = _results[index];
                final thumb = video.thumbnails.mediumResUrl;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 88,
                      height: 50,
                      child: thumb.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white38,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.white10,
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${video.author} · ${_formatDuration(video.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.red,
                    size: 28,
                  ),
                  onTap: () => widget.onPlayVideo(video.id.value),
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Or paste link',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'YouTube URL or video ID',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _playFromUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Play'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
