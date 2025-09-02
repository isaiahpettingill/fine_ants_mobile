class PeriodRange {
  final DateTime start;
  final DateTime endExclusive;

  PeriodRange(this.start, this.endExclusive);
}

/// Returns the current period range for the given period string.
/// period: 'week' | 'month' | 'year'
PeriodRange currentPeriodRange(String period, {DateTime? now}) {
  final n = now ?? DateTime.now();
  switch (period) {
    case 'week':
      return _currentWeek(n);
    case 'month':
      return _currentMonth(n);
    case 'year':
      return _currentYear(n);
    default:
      return _currentMonth(n);
  }
}

PeriodRange _currentWeek(DateTime n) {
  // ISO week: Monday as first day (1). DateTime.weekday: Mon=1..Sun=7
  final start = DateTime(
    n.year,
    n.month,
    n.day,
  ).subtract(Duration(days: n.weekday - 1));
  final end = start.add(const Duration(days: 7));
  return PeriodRange(start, end);
}

PeriodRange _currentMonth(DateTime n) {
  final start = DateTime(n.year, n.month, 1);
  final end = DateTime(n.year, n.month + 1, 1);
  return PeriodRange(start, end);
}

PeriodRange _currentYear(DateTime n) {
  final start = DateTime(n.year, 1, 1);
  final end = DateTime(n.year + 1, 1, 1);
  return PeriodRange(start, end);
}
