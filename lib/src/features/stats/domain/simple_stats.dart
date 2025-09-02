import 'package:flutter/foundation.dart';

@immutable
class SimpleStats {
  final String currencyCode;
  final int spentThisMonthMinor;
  final int spentThisYearMinor;
  final double budgetsMetPercent; // 0..100
  final int savedMinor; // sum of (budget - spent) where spent <= budget
  final double?
  earningSpendingRatio; // earned/spent for current month; null if spent==0

  const SimpleStats({
    required this.currencyCode,
    required this.spentThisMonthMinor,
    required this.spentThisYearMinor,
    required this.budgetsMetPercent,
    required this.savedMinor,
    required this.earningSpendingRatio,
  });
}
