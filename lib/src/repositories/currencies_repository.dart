import 'package:sqlite3/sqlite3.dart' as sqlite;

class CurrencyRow {
  final String code; // e.g., USD, EUR, BTC
  final String? symbol; // e.g., $, €, null for crypto
  final String symbolPosition; // 'before' | 'after'
  final int decimalPlaces; // e.g., 2 for fiat, 8 for BTC

  CurrencyRow({
    required this.code,
    required this.symbol,
    required this.symbolPosition,
    required this.decimalPlaces,
  });
}

class CurrenciesRepository {
  final sqlite.Database db;
  CurrenciesRepository(this.db);

  List<CurrencyRow> listAll() {
    final result = db.select(
      'SELECT code, symbol, symbol_position, decimal_places FROM currencies ORDER BY code ASC',
    );
    return [
      for (final row in result)
        CurrencyRow(
          code: row['code'] as String,
          symbol: row['symbol'] as String?,
          symbolPosition: row['symbol_position'] as String,
          decimalPlaces: row['decimal_places'] as int,
        )
    ];
  }

  CurrencyRow? getByCode(String code) {
    final result = db.select(
      'SELECT code, symbol, symbol_position, decimal_places FROM currencies WHERE code = ? LIMIT 1',
      [code],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return CurrencyRow(
      code: row['code'] as String,
      symbol: row['symbol'] as String?,
      symbolPosition: row['symbol_position'] as String,
      decimalPlaces: row['decimal_places'] as int,
    );
  }

  void create({
    required String code,
    String? symbol,
    required String symbolPosition,
    required int decimalPlaces,
  }) {
    final stmt = db.prepare(
      'INSERT INTO currencies (code, symbol, symbol_position, decimal_places) VALUES (?, ?, ?, ?)',
    );
    try {
      stmt.execute([code, symbol, symbolPosition, decimalPlaces]);
    } finally {
      stmt.dispose();
    }
  }

  void update({
    required String code,
    String? symbol,
    required String symbolPosition,
    required int decimalPlaces,
  }) {
    db.execute(
      'UPDATE currencies SET symbol = ?, symbol_position = ?, decimal_places = ? WHERE code = ?',
      [symbol, symbolPosition, decimalPlaces, code],
    );
  }

  void delete(String code) {
    db.execute('DELETE FROM currencies WHERE code = ?', [code]);
  }
}
