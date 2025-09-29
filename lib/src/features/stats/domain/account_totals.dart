import 'package:flutter/foundation.dart';

@immutable
class AccountTotals {
  final int accountId;
  final String accountName;
  final int earnedMinor;
  final int spentMinor;

  const AccountTotals({
    required this.accountId,
    required this.accountName,
    required this.earnedMinor,
    required this.spentMinor,
  });
}
