import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/pdf_viewer_widget.dart';
import '../widgets/text_quote_widget.dart';
import '../widgets/video_player_widget.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          playlist.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: playlist.resources.isEmpty
              ? const Center(child: Text('لا تحتوي هذه القائمة على مواد'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                  children: [
                    if (playlist.description?.isNotEmpty == true) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(
                          playlist.description!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                    for (final resource in playlist.resources)
                      switch (resource.type) {
                        'audio' => AudioPlayerWidget(resource: resource),
                        'video' => VideoPlayerWidget(resource: resource),
                        'pdf' => PdfViewerWidget(resource: resource),
                        'text' || _ => TextQuoteWidget(resource: resource),
                      },
                  ],
                ),
        ),
      ),
    );
  }
}
