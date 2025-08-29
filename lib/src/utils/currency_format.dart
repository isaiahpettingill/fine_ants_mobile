import '../repositories/currencies_repository.dart';

String formatAmount(double amount, CurrencyRow c) {
  final fixed = amount.toStringAsFixed(c.decimalPlaces);
  final symbol = c.symbol ?? '';
  if (symbol.isEmpty) {
    return '$fixed ${c.code}';
  }
  return c.symbolPosition == 'before' ? '$symbol$fixed' : '$fixed$symbol';
}

