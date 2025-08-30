import '../repositories/currencies_repository.dart';

String formatAmount(double amount, CurrencyRow c) {
  final fixed = amount.toStringAsFixed(c.decimalPlaces);
  final symbol = c.symbol ?? '';
  if (symbol.isEmpty) {
    return '$fixed ${c.code}';
  }
  return c.symbolPosition == 'before' ? '$symbol$fixed' : '$fixed$symbol';
}

/// Formats an amount in minor units (integer) using currency decimals.
String formatMinorUnits(int amountMinor, CurrencyRow c) {
  final d = c.decimalPlaces;
  if (d == 0) {
    final fixed = amountMinor.toString();
    final symbol = c.symbol ?? '';
    if (symbol.isEmpty) return '$fixed ${c.code}';
    return c.symbolPosition == 'before' ? '$symbol$fixed' : '$fixed$symbol';
  }
  final sign = amountMinor < 0 ? '-' : '';
  final abs = amountMinor.abs();
  final whole = abs ~/ pow10(d);
  final frac = (abs % pow10(d)).toString().padLeft(d, '0');
  final fixed = '$sign$whole.$frac';
  final symbol = c.symbol ?? '';
  if (symbol.isEmpty) return '$fixed ${c.code}';
  return c.symbolPosition == 'before' ? '$symbol$fixed' : '$fixed$symbol';
}

int pow10(int n) {
  var x = 1;
  for (var i = 0; i < n; i++) {
    x *= 10;
  }
  return x;
}

/// Parses a major-unit string (e.g., "12.34") to minor units integer
/// according to the currency's decimalPlaces. Rounds down extra precision.
int parseMajorToMinor(String text, CurrencyRow c) {
  final d = c.decimalPlaces;
  if (text.isEmpty) throw FormatException('Amount required');
  // Normalize: remove spaces, handle commas as thousand separators
  final cleaned = text.replaceAll(',', '').trim();
  if (d == 0) {
    final v = int.tryParse(cleaned);
    if (v == null) throw FormatException('Invalid amount');
    return v;
  }
  // Split on decimal point
  final parts = cleaned.split('.');
  final wholeStr = parts[0];
  final fracStr = parts.length > 1 ? parts[1] : '';
  final whole = int.tryParse(wholeStr);
  if (whole == null) throw FormatException('Invalid amount');
  final scale = pow10(d);
  final fracPadded = (fracStr.length >= d)
      ? fracStr.substring(0, d)
      : fracStr.padRight(d, '0');
  final frac = int.tryParse(fracPadded) ?? 0;
  final sign = cleaned.startsWith('-') ? -1 : 1;
  return sign * (whole.abs() * scale + frac);
}
