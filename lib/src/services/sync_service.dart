import 'dart:io';

import 'package:path/path.dart' as p;

import 'account_store.dart';
import 'saf_mirror_service.dart';

class SyncService {
  /// Copies each register DB to its mirror location when configured.
  /// Returns the number of registers synchronized.
  static Future<int> syncAll() async {
    final regs = AccountStore.instance.accounts;
    var count = 0;
    for (final reg in regs) {
      final mirror = reg.mirrorUri;
      if (mirror == null || mirror.isEmpty) continue;
      try {
        final dbFile = File(reg.dbPath);
        if (!await dbFile.exists()) continue;
        final bytes = await dbFile.readAsBytes();
        if (Platform.isAndroid && mirror.startsWith('content://')) {
          await SafMirrorService.writeFileToTree(
            treeUri: mirror,
            displayName: p.basename(reg.dbPath),
            mimeType: 'application/x-sqlite3',
            bytes: bytes,
          );
        } else {
          // Treat as filesystem directory path.
          final targetPath = p.join(mirror, p.basename(reg.dbPath));
          await File(targetPath).writeAsBytes(bytes, flush: true);
        }
        count++;
      } catch (_) {
        // Best-effort; continue syncing others.
      }
    }
    return count;
  }
}
