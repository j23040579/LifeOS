// Generate only missing platform runners with the installed Flutter SDK.
// Never run `flutter create .` over the approved source and tests.
import 'dart:io';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync() ||
      !File('lib/main.dart').existsSync()) {
    stderr.writeln('Run from the LifeOS repository root.');
    exitCode = 1;
    return;
  }
  final missing = [
    'android',
    'windows',
    'web',
  ].where((name) => !Directory(name).existsSync()).toList();
  if (Directory('web').existsSync()) await _databaseAssets();
  await _androidNetworking();
  if (missing.isEmpty) {
    stdout.writeln(
      'All platform directories already exist; no runners regenerated.',
    );
    return;
  }
  final temp = await Directory.systemTemp.createTemp('lifeos-platforms-');
  try {
    final generated = Directory('${temp.path}/lifeos');
    final result = await Process.start(
      'flutter',
      [
        'create',
        '--empty',
        '--no-pub',
        '--platforms=${missing.join(',')}',
        '--org=com.example',
        '--project-name=lifeos',
        generated.path,
      ],
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final status = await result.exitCode;
    if (status != 0) {
      exitCode = status;
      return;
    }
    // Validate the generated files before copying any platform.
    final gradle = File('${generated.path}/android/app/build.gradle.kts');
    final oldGradle = File('${generated.path}/android/app/build.gradle');
    if (missing.contains('android')) {
      final file = gradle.existsSync() ? gradle : oldGradle;
      if (!file.existsSync()) {
        throw StateError('Unrecognized Android template: no app Gradle file.');
      }
      final contents = await file.readAsString();
      final matcher = RegExp(r'minSdk\s*=\s*flutter.minSdkVersion');
      final legacyMatcher = RegExp(r'minSdkVersion\s+flutter.minSdkVersion');
      if (!matcher.hasMatch(contents) && !legacyMatcher.hasMatch(contents)) {
        throw StateError('Unrecognized Android minimum SDK template.');
      }
      await file.writeAsString(
        contents
            .replaceAll(
              matcher,
              gradle.existsSync()
                  ? 'minSdk = maxOf(26, flutter.minSdkVersion)'
                  : 'minSdk = Math.max(26, flutter.minSdkVersion)',
            )
            .replaceAll(
              legacyMatcher,
              'minSdkVersion Math.max(26, flutter.minSdkVersion)',
            ),
      );
    }
    for (final platform in missing) {
      await _copy(
        Directory('${generated.path}/$platform'),
        Directory(platform),
      );
      stdout.writeln('Created $platform runner.');
    }
    await _androidNetworking();
    await _databaseAssets();
    stdout.writeln(
      'Source, tests, pubspec, and existing runners were preserved.',
    );
  } finally {
    await temp.delete(recursive: true);
  }
}

Future<void> _copy(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entry in source.list(followLinks: false)) {
    final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
    final path = '${destination.path}/$name';
    if (entry is Directory) {
      await _copy(entry, Directory(path));
    } else if (entry is File) {
      await entry.copy(path);
    } else {
      throw StateError('Unexpected link in generated platform: ${entry.path}');
    }
  }
}

Future<void> _databaseAssets() async {
  for (final name in ['sqlite3.wasm', 'drift_worker.js']) {
    final source = File('third_party/sqlite/$name');
    final destination = File('web/$name');
    if (!source.existsSync())
      throw StateError('Missing bundled database asset: $name');
    if (destination.existsSync()) {
      final a = await source.readAsBytes(), b = await destination.readAsBytes();
      if (a.length != b.length ||
          List.generate(a.length, (i) => a[i] == b[i]).contains(false)) {
        throw StateError(
          'Existing web/$name differs. Preserve it before updating the SQLite runtime.',
        );
      }
    } else {
      await source.copy(destination.path);
    }
  }
}

// Add the permission required by optional HTTPS AI in release builds. Existing
// manifest attributes and runner files are preserved; cleartext stays disabled.
Future<void> _androidNetworking() async {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) return;
  final original = await file.readAsString();
  var text = original;
  if (!text.contains('android.permission.INTERNET')) {
    final at = text.indexOf('>');
    if (at < 0 || !text.startsWith('<manifest'))
      throw StateError(
        'Unrecognized Android manifest; add INTERNET permission manually.',
      );
    text = text.replaceRange(
      at + 1,
      at + 1,
      '\n    <uses-permission android:name="android.permission.INTERNET"/>',
    );
  }
  final application = RegExp(r'<application\b[^>]*>').firstMatch(text);
  if (application == null)
    throw StateError('No Android application manifest element.');
  var tag = application.group(0)!;
  final backup = RegExp(r'android:allowBackup="[^"]*"');
  tag = backup.hasMatch(tag)
      ? tag.replaceFirst(backup, 'android:allowBackup="false"')
      : tag.replaceFirst(
          '<application',
          '<application android:allowBackup="false"',
        );
  text = text.replaceRange(application.start, application.end, tag);
  if (text != original) {
    await file.writeAsString(text);
    stdout.writeln(
      'Configured Android HTTPS access and disabled automatic backup; use explicit local JSON backups.',
    );
  }
}
