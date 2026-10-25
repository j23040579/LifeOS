import 'dart:io';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:lifeos/data/documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PDF extraction preserves page references and readable content',
    () async {
      final cache = await Directory.systemTemp.createTemp('lifeos-pdf-');
      Pdfrx.cacheDirectoryPath = cache.path;
      // Flutter's test runner is not an installed desktop app. Use the official
      // hook-produced module through pdfrx's documented test override.
      final platform = Platform.isWindows
          ? 'win'
          : Platform.isMacOS
          ? 'mac'
          : 'linux';
      final arch = Abi.current().toString().contains('arm64') ? 'arm64' : 'x64';
      final library = Platform.isWindows
          ? 'pdfium.dll'
          : Platform.isMacOS
          ? 'libpdfium.dylib'
          : 'libpdfium.so';
      final modules =
          Directory('.dart_tool/hooks_runner/shared/pdfium_dart/build')
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (file) =>
                    file.path
                        .replaceAll('\\', '/')
                        .contains('/$platform-$arch/') &&
                    file.path.endsWith(library),
              )
              .toList();
      if (modules.isNotEmpty)
        Pdfrx.pdfiumModulePath = modules.first.absolute.path;
      try {
        final bytes = await File('test/fixtures/lecture_sample.pdf')
            .readAsBytes();
        final result = await DocumentImporter().extract('lecture.pdf', bytes);
        expect(result.records, hasLength(1));
        expect(result.records.single['reference'], 'Page 1 of 1');
        expect(result.records.single['body'], contains('linked lists'));
      } finally {
        await cache.delete(recursive: true);
      }
    },
  );
  test(
    'EPUB follows reading order and retains author/section provenance',
    () async {
      final bytes = await File('test/fixtures/book_sample.epub').readAsBytes();
      final result = await DocumentImporter().extract('book.epub', bytes);
      expect(result.records, hasLength(1));
      expect(result.records.single['source'], contains('Synthetic sample'));
      expect(
        result.records.single['body'],
        contains('Explain an idea from memory'),
      );
      expect(
        result.records.single['body'],
        isNot(contains('must not be imported')),
      );
    },
  );
}
