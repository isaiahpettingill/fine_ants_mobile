import 'dart:convert';
import 'dart:io';

import '../models/account.dart';

class AccountStore {
  AccountStore._(this._rootDir);

  static late final AccountStore instance;
  static Future<void> initialize(String rootDir) async {
    instance = AccountStore._(rootDir);
  }

  final String _rootDir;
  final List<Account> accounts = [];

  File get _storeFile => File('$_rootDir/accounts.json');

  Future<void> load() async {
    try {
      if (await _storeFile.exists()) {
        final content = await _storeFile.readAsString();
        final data = jsonDecode(content) as Map<String, Object?>;
        final list = (data['accounts'] as List).cast<Map<String, Object?>>();
        accounts
          ..clear()
          ..addAll(list.map(Account.fromJson));
      }
    } catch (_) {
      // Start fresh on any parse error
      accounts.clear();
    }
  }

  Future<void> save() async {
    final dir = Directory(_rootDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final payload = {
      'accounts': accounts.map((a) => a.toJson()).toList(),
    };
    await _storeFile.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }
}

