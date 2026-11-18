import 'resource_model.dart';

class PlaylistModel {
  final int id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final DateTime createdAt;
  final List<ResourceModel> resources;

  const PlaylistModel({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.createdAt,
    this.resources = const [],
  });

  factory PlaylistModel.fromJson(
    Map<String, dynamic> json, {
    List<ResourceModel> resources = const [],
  }) {
    return PlaylistModel(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      resources: resources,
    );
  }
}
