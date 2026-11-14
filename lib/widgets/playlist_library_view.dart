import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../screens/playlist_detail_screen.dart';

class PlaylistLibraryView extends StatelessWidget {
  final List<PlaylistModel> playlists;
  final String? error;
  final bool isLoading;
  final Future<void> Function() onRetry;

  const PlaylistLibraryView({
    super.key,
    required this.playlists,
    required this.error,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF59E0B);
    if (isLoading && playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: gold));
    }
    if (error != null && playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42, color: gold),
              const SizedBox(height: 12),
              const Text(
                'تعذر تحميل قوائم التشغيل. تأكد من إعداد قاعدة البيانات ثم أعد المحاولة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (playlists.isEmpty) {
      return const Center(child: Text('لا توجد قوائم تشغيل بعد'));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1AF59E0B),
                  child: Icon(Icons.queue_music_rounded, color: gold),
                ),
                title: Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${playlist.resources.length} مادة${playlist.description?.isNotEmpty == true ? ' • ${playlist.description}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlist: playlist),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
