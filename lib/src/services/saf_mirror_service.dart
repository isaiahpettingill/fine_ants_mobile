import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SafMirrorService {
  static const MethodChannel _channel = MethodChannel('fine_ants_mobile/saf');

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static Future<void> persistPermission(String treeUri) async {
    if (!isAndroid) return;
    await _channel.invokeMethod('persistUriPermission', {'treeUri': treeUri});
  }

  static Future<void> writeFileToTree({
    required String treeUri,
    required String displayName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (!isAndroid) return;
    await _channel.invokeMethod('writeFileToTree', {
      'treeUri': treeUri,
      'displayName': displayName,
      'mimeType': mimeType,
      'bytes': bytes,
    });
  }
}
