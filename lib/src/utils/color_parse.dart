import 'package:flutter/material.dart';

/// Parses a hex color string like '#RRGGBB' or 'RRGGBB' into a [Color].
Color parseHexColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((ch) => ch * 2).join();
  }
  final value = int.tryParse(h, radix: 16) ?? 0x000000;
  return Color(0xFF000000 | value);
}
