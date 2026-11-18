import 'package:flutter_test/flutter_test.dart';
import 'package:al_atheer/utils/daily_quote_selector.dart';

void main() {
  const quotes = [
    {'id': '1', 'title': 'First', 'quote': 'Quote one', 'source': ''},
    {'id': '2', 'title': 'Second', 'quote': 'Quote two', 'source': ''},
    {'id': '3', 'title': 'Third', 'quote': 'Quote three', 'source': ''},
    {'id': '4', 'title': 'Fourth', 'quote': 'Quote four', 'source': ''},
  ];
  final epoch = DateTime.utc(2000, 1, 1);
  DateTime day(int offset) => epoch.add(Duration(days: offset));

  test('uses the scheduled quote even when it is outside the random pool', () {
    final selected = DailyQuoteSelector.select(
      curatedQuotes: quotes,
      randomPool: [quotes[0], quotes[1]],
      schedule: {day(0): 4},
      date: day(0),
    );

    expect(selected?['id'], '4');
  });

  test('does not repeat random quotes before a cycle is exhausted', () {
    final pool = [quotes[0], quotes[1], quotes[2]];
    final schedule = {day(1): 4};
    final selectedIds = [
      DailyQuoteSelector.select(
        curatedQuotes: quotes,
        randomPool: pool,
        schedule: schedule,
        date: day(0),
      )!['id'],
      DailyQuoteSelector.select(
        curatedQuotes: quotes,
        randomPool: pool,
        schedule: schedule,
        date: day(2),
      )!['id'],
      DailyQuoteSelector.select(
        curatedQuotes: quotes,
        randomPool: pool,
        schedule: schedule,
        date: day(3),
      )!['id'],
    ];

    expect(selectedIds.toSet(), hasLength(pool.length));
  });

  test('avoids the scheduled quote from yesterday when possible', () {
    final pool = [quotes[0], quotes[1], quotes[2]];
    final yesterdayQuote = DailyQuoteSelector.select(
      curatedQuotes: quotes,
      randomPool: pool,
      schedule: const {},
      date: day(0),
    )!;
    final todayQuote = DailyQuoteSelector.select(
      curatedQuotes: quotes,
      randomPool: pool,
      schedule: {day(1): int.parse(yesterdayQuote['id']!)},
      date: day(2),
    )!;

    expect(todayQuote['id'], isNot(yesterdayQuote['id']));
  });

  test('starts a new cycle with a different quote from the prior cycle', () {
    final pool = [quotes[0], quotes[1], quotes[2]];
    final selectedIds = List.generate(
      6,
      (offset) => DailyQuoteSelector.select(
        curatedQuotes: quotes,
        randomPool: pool,
        schedule: const {},
        date: day(offset),
      )!['id'],
    );

    expect(selectedIds.sublist(0, 3).toSet(), hasLength(3));
    expect(selectedIds.sublist(3, 6).toSet(), hasLength(3));
    for (var index = 1; index < selectedIds.length; index++) {
      expect(selectedIds[index], isNot(selectedIds[index - 1]));
    }
  });
}
