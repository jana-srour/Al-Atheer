import 'package:al_atheer/models/azkar_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Azkar without a category do not get a seeded category', () {
    final item = AzkarModel.fromJson({
      'id': 41,
      'title': 'Reminder',
      'content': 'Remember',
      'scheduled_at': '2026-11-18T08:30:00Z',
    });

    expect(item.category, isEmpty);
  });

  test('Azkar schedule round-trips its time and reminder details', () {
    final item = AzkarModel.fromJson({
      'id': 42,
      'title': 'Morning remembrance',
      'content': 'A remembrance',
      'description': 'Read with reflection',
      'source': 'Reference',
      'repetition_count': 3,
      'category': 'Morning',
      'scheduled_at': '2026-11-18T08:30:00Z',
    });

    expect(item.id, 42);
    expect(item.repetitionCount, 3);
    expect(item.scheduledAt.toUtc(), DateTime.utc(2026, 11, 18, 8, 30));
    expect(item.toJson()['source'], 'Reference');
    expect(
      item.toJson()['scheduled_at'],
      DateTime.utc(2026, 11, 18, 8, 30).toIso8601String(),
    );
  });
}
