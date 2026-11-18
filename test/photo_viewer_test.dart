import 'package:al_atheer/widgets/editorial_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a post photo opens its gallery in the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorialPhoto(
            imageUrl: 'https://example.com/second.jpg',
            galleryImages: const [
              'https://example.com/first.jpg',
              'https://example.com/second.jpg',
            ],
            initialIndex: 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byTooltip('إغلاق'), findsOneWidget);

    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsNothing);
  });
}
