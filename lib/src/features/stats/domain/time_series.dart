import 'package:flutter/foundation.dart';

@immutable
class TimeSeriesPoint {
  final DateTime x;
  final int yMinor; // value in minor units
  const TimeSeriesPoint({required this.x, required this.yMinor});
}

enum SeriesPeriod { month, week, day }

@immutable
class BudgetAdherencePoint {
  final DateTime x;
  final int spentMinor;
  final int budgetMinor;
  const BudgetAdherencePoint({
    required this.x,
    required this.spentMinor,
    required this.budgetMinor,
  });
}

@immutable
class EarningSpendingPoint {
  final DateTime x;
  final int earnedMinor;
  final int spentMinor;
  final double? ratio; // earned / spent; null if spent==0
  const EarningSpendingPoint({
    required this.x,
    required this.earnedMinor,
    required this.spentMinor,
  }) : ratio = spentMinor == 0 ? null : earnedMinor / spentMinor;
}

extension SeriesPeriodExt on SeriesPeriod {
  DateTime floor(DateTime dt) {
    switch (this) {
      case SeriesPeriod.month:
        return DateTime(dt.year, dt.month);
      case SeriesPeriod.week:
        final weekday = dt.weekday; // Monday=1 .. Sunday=7
        final start = dt.subtract(Duration(days: weekday - 1));
        return DateTime(start.year, start.month, start.day);
      case SeriesPeriod.day:
        return DateTime(dt.year, dt.month, dt.day);
    }
  }

  DateTime next(DateTime dt) {
    switch (this) {
      case SeriesPeriod.month:
        return DateTime(dt.year, dt.month + 1);
      case SeriesPeriod.week:
        return dt.add(const Duration(days: 7));
      case SeriesPeriod.day:
        return dt.add(const Duration(days: 1));
    }
  }
}
