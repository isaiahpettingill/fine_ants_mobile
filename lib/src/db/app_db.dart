import 'package:sqlite3/sqlite3.dart' as sqlite;

class AppDb {
  final String path;
  sqlite.Database? _db;

  AppDb(this.path);

  sqlite.Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('Database is not open');
    }
    return d;
  }

  Future<void> open() async {
    _db ??= sqlite.sqlite3.open(path);
  }

  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }
}

