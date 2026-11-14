import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../providers/auth_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/playlist_library_view.dart';

class PlaylistLibraryScreen extends StatelessWidget {
  const PlaylistLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final playlists =
        settings.hideProcessingFromPublic &&
            (!auth.isAuthenticated || !auth.isAdmin)
        ? provider.playlists
              .map(
                (playlist) => PlaylistModel(
                  id: playlist.id,
                  title: playlist.title,
                  description: playlist.description,
                  createdAt: playlist.createdAt,
                  resources: playlist.resources
                      .where(
                        (resource) => provider.isResourceReady(
                          resource,
                          delaySeconds: settings.archiveIngestionDelaySeconds,
                        ),
                      )
                      .toList(),
                ),
              )
              .toList()
        : provider.playlists;
    return Scaffold(
      appBar: AppBar(title: const Text('قوائم التشغيل والدورات')),
      body: PlaylistLibraryView(
        playlists: playlists,
        error: provider.playlistsError,
        isLoading: provider.isLoadingPlaylists,
        onRetry: provider.fetchPlaylists,
      ),
    );
  }
}
