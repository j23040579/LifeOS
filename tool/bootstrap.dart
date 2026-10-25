// Generate only missing platform runners with the installed Flutter SDK.
// Never run `flutter create .` over the approved source and tests.
import 'dart:io';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync() || !File('lib/main.dart').existsSync()) {
    stderr.writeln('Run from the LifeOS repository root.');
    exitCode = 1;
    return;
  }
  final missing = ['android', 'windows', 'web']
      .where((name) => !Directory(name).existsSync())
      .toList();
  if (missing.isEmpty) {
    stdout.writeln('All platform directories already exist; nothing overwritten.');
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
      await file.writeAsString(contents
          .replaceAll(
              matcher,
              gradle.existsSync()
                  ? 'minSdk = maxOf(26, flutter.minSdkVersion)'
                  : 'minSdk = Math.max(26, flutter.minSdkVersion)')
          .replaceAll(legacyMatcher,
              'minSdkVersion Math.max(26, flutter.minSdkVersion)'));
    }
    for (final platform in missing) {
      await _copy(Directory('${generated.path}/$platform'), Directory(platform));
      stdout.writeln('Created $platform runner.');
    }
    stdout.writeln('Source, tests, pubspec, and existing runners were preserved.');
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
