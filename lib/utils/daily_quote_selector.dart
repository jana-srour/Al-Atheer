import 'dart:math';

class DailyQuoteSelector {
  static final _epoch = DateTime.utc(2000, 1, 1);

  static Map<String, String>? select({
    required List<Map<String, String>> curatedQuotes,
    required List<Map<String, String>> randomPool,
    required Map<DateTime, int> schedule,
    required DateTime date,
  }) {
    final day = _dateOnly(date);
    final scheduledQuoteId = schedule[day];
    if (scheduledQuoteId != null) {
      for (final quote in curatedQuotes) {
        if (int.tryParse(quote['id'] ?? '') == scheduledQuoteId) {
          return quote;
        }
      }
    }

    final quotes =
        randomPool
            .where((quote) => int.tryParse(quote['id'] ?? '') != null)
            .toList()
          ..sort(
            (left, right) =>
                int.parse(left['id']!).compareTo(int.parse(right['id']!)),
          );
    if (quotes.isEmpty || day.isBefore(_epoch)) return null;

    final scheduledDaysBeforeToday = schedule.keys
        .map(_dateOnly)
        .where(
          (scheduledDay) =>
              !scheduledDay.isBefore(_epoch) && !scheduledDay.isAfter(day),
        )
        .length;
    final unscheduledOrdinal =
        day.difference(_epoch).inDays - scheduledDaysBeforeToday;
    final cycleLength = quotes.length;
    final cycle = unscheduledOrdinal ~/ cycleLength;
    final slot = unscheduledOrdinal % cycleLength;
    final order = _cycleOrder(quotes, cycle);

    var cycleStart = day;
    var earlierUnscheduledDays = slot;
    while (earlierUnscheduledDays > 0) {
      cycleStart = cycleStart.subtract(const Duration(days: 1));
      if (!schedule.containsKey(cycleStart)) earlierUnscheduledDays--;
    }

    final previousDay = cycleStart.subtract(const Duration(days: 1));
    var previousQuoteId = schedule[_dateOnly(previousDay)];
    if (previousQuoteId == null && cycle > 0) {
      previousQuoteId = _cycleOrder(quotes, cycle - 1).last;
    }
    if (cycle > 0 && order.length > 1 && order.first == previousQuoteId) {
      final first = order.removeAt(0);
      order.insert(1, first);
    }

    final usedInCycle = <int>{};
    var selectedQuoteId = order.first;
    for (
      var currentDay = cycleStart;
      !currentDay.isAfter(day);
      currentDay = currentDay.add(const Duration(days: 1))
    ) {
      final scheduledId = schedule[_dateOnly(currentDay)];
      if (scheduledId != null) {
        previousQuoteId = scheduledId;
        continue;
      }

      final available = order
          .where((quoteId) => !usedInCycle.contains(quoteId))
          .toList();
      final alternatives = available
          .where((quoteId) => quoteId != previousQuoteId)
          .toList();
      selectedQuoteId =
          (alternatives.isNotEmpty ? alternatives : available).first;
      usedInCycle.add(selectedQuoteId);
      previousQuoteId = selectedQuoteId;
    }

    return quotes.firstWhere(
      (quote) => int.parse(quote['id']!) == selectedQuoteId,
    );
  }

  static List<int> _cycleOrder(List<Map<String, String>> quotes, int cycle) {
    var seed = 0x5eed;
    for (final quote in quotes) {
      seed = ((seed * 31) ^ int.parse(quote['id']!)) & 0x7fffffff;
    }
    seed = ((seed * 31) ^ cycle) & 0x7fffffff;
    final quoteIds = quotes.map((quote) => int.parse(quote['id']!)).toList();
    return quoteIds..shuffle(Random(seed));
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
