class AzkarModel {
  final int id;
  final String title;
  final String content;
  final String? description;
  final String? source;
  final int repetitionCount;
  final String category;
  final DateTime scheduledAt;

  const AzkarModel({
    required this.id,
    required this.title,
    required this.content,
    this.description,
    this.source,
    required this.repetitionCount,
    required this.category,
    required this.scheduledAt,
  });

  factory AzkarModel.fromJson(Map<String, dynamic> json) => AzkarModel(
    id: (json['id'] as num).toInt(),
    title: json['title']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    description: json['description']?.toString(),
    source: json['source']?.toString(),
    repetitionCount: (json['repetition_count'] as num?)?.toInt() ?? 1,
    category: json['category']?.toString() ?? '',
    scheduledAt: DateTime.parse(json['scheduled_at'].toString()).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'description': description,
    'source': source,
    'repetition_count': repetitionCount,
    'category': category,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
  };
}
