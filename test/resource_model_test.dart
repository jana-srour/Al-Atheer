import 'package:flutter_test/flutter_test.dart';
import 'package:al_atheer/models/resource_model.dart';
import 'package:al_atheer/services/archive_upload_service.dart';

void main() {
  test('legacy resources load without attachment metadata', () {
    final resource = ResourceModel.fromJson({
      'id': 7,
      'title': 'Legacy PDF',
      'type': 'pdf',
      'archive_url': 'https://archive.org/download/item/book.pdf',
      'category': 'Fiqh',
      'created_at': '2025-01-01T00:00:00Z',
    });

    expect(resource.attachments, isEmpty);
    expect(resource.archiveUrl, contains('book.pdf'));
  });

  test('mixed post attachments round-trip through the resource model', () {
    final resource = ResourceModel.fromJson({
      'id': 8,
      'title': 'Mixed post',
      'type': 'post',
      'text_content': 'Post text',
      'attachments': [
        {
          'type': 'image',
          'url': 'https://archive.org/download/item/photo.jpg',
          'file_name': 'photo.jpg',
        },
        {
          'type': 'audio',
          'url': 'https://archive.org/download/item/audio.mp3',
          'file_name': 'audio.mp3',
        },
      ],
      'category': 'Fiqh',
      'created_at': '2025-01-01T00:00:00Z',
    });

    expect(resource.textContent, 'Post text');
    expect(resource.attachments.map((item) => item.type), ['image', 'audio']);
    expect(resource.coverUrl, 'https://archive.org/download/item/photo.jpg');
    expect(resource.toJson()['attachments'], [
      {
        'type': 'image',
        'url': 'https://archive.org/download/item/photo.jpg',
        'file_name': 'photo.jpg',
      },
      {
        'type': 'audio',
        'url': 'https://archive.org/download/item/audio.mp3',
        'file_name': 'audio.mp3',
      },
    ]);
  });

  test('post cover override and removal are honored', () {
    final resource = ResourceModel.fromJson({
      'id': 9,
      'title': 'Post with custom cover',
      'type': 'post',
      'cover_image_url': 'https://archive.org/download/item/cover.jpg',
      'attachments': [
        {
          'type': 'image',
          'url': 'https://archive.org/download/item/photo.jpg',
          'file_name': 'photo.jpg',
        },
      ],
      'category': 'Fiqh',
      'created_at': '2025-01-01T00:00:00Z',
    });
    final hiddenResource = ResourceModel.fromJson({
      'id': 10,
      'title': 'Post with no cover',
      'type': 'post',
      'cover_image_hidden': true,
      'attachments': [
        {
          'type': 'image',
          'url': 'https://archive.org/download/item/photo.jpg',
          'file_name': 'photo.jpg',
        },
      ],
      'category': 'Fiqh',
      'created_at': '2025-01-01T00:00:00Z',
    });

    expect(resource.coverUrl, 'https://archive.org/download/item/cover.jpg');
    expect(hiddenResource.coverUrl, isNull);
  });

  test('photo extensions use Archive.org image metadata', () {
    expect(ArchiveUploadService.getMediaTypeInfo('jpg'), {
      'mediatype': 'image',
      'mime': 'image/jpeg',
      'appType': 'image',
    });
    expect(ArchiveUploadService.getMediaTypeInfo('png')['appType'], 'image');
    expect(ArchiveUploadService.getMediaTypeInfo('webp')['appType'], 'image');
    expect(ArchiveUploadService.getMediaTypeInfo('jpeg')['mime'], 'image/jpeg');
  });
}
