class ResourceModel {
  final int id;
  final String title;
  final String? description;
  final String type; // 'audio', 'video', 'pdf', 'text'
  final String? archiveUrl;
  final String? textContent;
  final String category;
  final DateTime createdAt;

  ResourceModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.archiveUrl,
    this.textContent,
    required this.category,
    required this.createdAt,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ResourceModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'text',
      archiveUrl: json['archive_url'],
      textContent: json['text_content'],
      category: json['category'] ?? 'General',
      createdAt: parsedDate,
    );
  }

  factory ResourceModel.fromMap(Map<String, dynamic> map) =>
      ResourceModel.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'archive_url': archiveUrl,
      'text_content': textContent,
      'category': category,
    };
  }

  /// Whether this media is still in the Archive.org backend ingestion / processing window
  bool isProcessing({int delaySeconds = 120}) {
    if (type == 'text' || archiveUrl == null || archiveUrl!.isEmpty) {
      return false;
    }
    final elapsedSeconds = DateTime.now().difference(createdAt).inSeconds;
    return elapsedSeconds >= 0 && elapsedSeconds < delaySeconds;
  }

  /// Remaining seconds before Archive.org indexing is fully ready
  int remainingProcessingSeconds({int delaySeconds = 120}) {
    if (type == 'text' || archiveUrl == null || archiveUrl!.isEmpty) {
      return 0;
    }
    final elapsedSeconds = DateTime.now().difference(createdAt).inSeconds;
    final remaining = delaySeconds - elapsedSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Ingestion progress fraction from 0.0 to 1.0
  double processingProgress({int delaySeconds = 120}) {
    if (type == 'text' || archiveUrl == null || archiveUrl!.isEmpty) {
      return 1.0;
    }
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    if (elapsed <= 0) return 0.05;
    if (elapsed >= delaySeconds) return 1.0;
    return (elapsed / delaySeconds).clamp(0.05, 1.0);
  }

  /// Formatted remaining countdown string (e.g. "01:45")
  String formattedRemainingTime({int delaySeconds = 120}) {
    final seconds = remainingProcessingSeconds(delaySeconds: delaySeconds);
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  /// Informative localized type label
  String get typeLabel {
    switch (type) {
      case 'pdf':
        return 'كتاب / وثيقة PDF';
      case 'audio':
        return 'تسجيل صوتي';
      case 'video':
        return 'مرئي / درس مصور';
      case 'text':
      default:
        return 'اقتباس وفائدة علمية';
    }
  }

  /// Formatted date in Arabic/English
  String get formattedDate {
    final y = createdAt.year;
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }
}
