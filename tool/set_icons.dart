import 'dart:io';

void main(List<String> args) async {
  final srcRoot = Directory('new_icons');
  if (!srcRoot.existsSync()) {
    stderr.writeln('new_icons folder not found at ${srcRoot.path}');
    exitCode = 1;
    return;
  }

  // Android mipmaps
  final androidDensities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
  for (final density in androidDensities) {
    final src = File('new_icons/android/mipmap-$density/ic_launcher.png');
    final dst = File(
      'android/app/src/main/res/mipmap-$density/ic_launcher.png',
    );
    if (src.existsSync()) {
      await dst.parent.create(recursive: true);
      await src.copy(dst.path);
      stdout.writeln('Android: copied $density icon');
    } else {
      stdout.writeln('Android: skip $density (source missing)');
    }
  }

  // iOS and macOS AppIcon.appiconset
  final appIconSetSrc = Directory(
    'new_icons/Assets.xcassets/AppIcon.appiconset',
  );
  final appIconImagesSrc = Directory(
    'new_icons/Assets.xcassets/AppIcon.appiconset/_',
  ); // images are under _/
  final contentsJsonSrc = File(
    'new_icons/Assets.xcassets/AppIcon.appiconset/Contents.json',
  );

  Future<void> copyAppIconSet(String platformDir) async {
    final destSetDir = Directory(
      '$platformDir/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    if (!appIconSetSrc.existsSync()) {
      stdout.writeln('$platformDir: AppIcon source not found, skipping');
      return;
    }
    await destSetDir.create(recursive: true);
    // Remove old PNGs to avoid stale images.
    for (final f in destSetDir.listSync()) {
      if (f is File && f.path.toLowerCase().endsWith('.png')) {
        await f.delete();
      }
    }
    if (contentsJsonSrc.existsSync()) {
      await contentsJsonSrc.copy('${destSetDir.path}/Contents.json');
    }
    if (appIconImagesSrc.existsSync()) {
      for (final f in appIconImagesSrc.listSync()) {
        if (f is File && f.path.toLowerCase().endsWith('.png')) {
          final name = f.uri.pathSegments.last;
          await f.copy('${destSetDir.path}/$name');
        }
      }
      stdout.writeln('$platformDir: AppIcon.appiconset updated');
    } else {
      stdout.writeln(
        '$platformDir: images folder missing, skipping image copy',
      );
    }
  }

  await copyAppIconSet('ios');
  await copyAppIconSet('macos');

  // Windows ICO
  final winSrc = File('new_icons/app_icon.ico');
  final winDst = File('windows/runner/resources/app_icon.ico');
  if (winSrc.existsSync()) {
    await winDst.parent.create(recursive: true);
    await winSrc.copy(winDst.path);
    stdout.writeln('Windows: app_icon.ico updated');
  } else {
    stdout.writeln('Windows: source ICO missing, skipping');
  }

  // Web icons
  final webDir = Directory('web');
  if (webDir.existsSync()) {
    final webIconsDir = Directory('web/icons');
    await webIconsDir.create(recursive: true);
    final src196 = File(
      'new_icons/Assets.xcassets/AppIcon.appiconset/_/196.png',
    );
    final src512 = File(
      'new_icons/Assets.xcassets/AppIcon.appiconset/_/512.png',
    );
    final src48 = File('new_icons/Assets.xcassets/AppIcon.appiconset/_/48.png');
    if (src196.existsSync()) {
      await src196.copy('web/icons/Icon-192.png');
      await src196.copy('web/icons/Icon-maskable-192.png');
    } else {
      stdout.writeln('Web: 196.png not found, skipping 192-sized icons');
    }
    if (src512.existsSync()) {
      await src512.copy('web/icons/Icon-512.png');
      await src512.copy('web/icons/Icon-maskable-512.png');
    } else {
      stdout.writeln('Web: 512.png not found, skipping 512-sized icons');
    }
    if (src48.existsSync()) {
      await src48.copy('web/favicon.png');
    } else {
      stdout.writeln('Web: 48.png not found, skipping favicon');
    }
  } else {
    stdout.writeln('Web: web/ directory not found, skipping');
  }

  // Linux: Not explicitly handled by Flutter template; many distros use packaging
  // metadata. If needed, add packaging-specific icons in your CI/release step.

  stdout.writeln('Icon sync complete.');
}
