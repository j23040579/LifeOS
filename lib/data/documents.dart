import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import '../domain/imports.dart';

class DocumentImporter {
  Future<ImportPreview> extract(String filename, Uint8List bytes) async {
    if (bytes.length > 5 * 1024 * 1024)
      throw const FormatException('Choose a document smaller than 5 MB.');
    final checksum = shaForBytes(bytes);
    if (filename.toLowerCase().endsWith('.pdf'))
      return _pdf(filename, bytes, checksum);
    if (filename.toLowerCase().endsWith('.epub'))
      return _epub(filename, bytes, checksum);
    throw const FormatException('Choose a PDF or EPUB file.');
  }

  Future<ImportPreview> _pdf(
    String filename,
    Uint8List bytes,
    String checksum,
  ) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(bytes, sourceName: checksum);
    try {
      if (document.pages.length > 200)
        throw const FormatException(
          'Split PDFs larger than 200 pages before importing.',
        );
      final records = <Map<String, dynamic>>[], diagnostics = <String>[];
      var characters = 0;
      for (var index = 0; index < document.pages.length; index++) {
        final text =
            (await document.pages[index].loadText())?.fullText.trim() ?? '';
        if (text.isEmpty) {
          diagnostics.add(
            'Page ${index + 1}: no extractable text (OCR may be needed).',
          );
          continue;
        }
        characters += text.length;
        if (characters > 1000000)
          throw const FormatException(
            'Document text is too large. Import smaller sections.',
          );
        records.add(
          _note(
            checksum,
            index,
            '$filename · Page ${index + 1}',
            filename,
            'Page ${index + 1} of ${document.pages.length}',
            text,
          ),
        );
      }
      if (records.isEmpty)
        throw const FormatException(
          'No extractable text. Scanned PDFs need OCR or a text alternative.',
        );
      return ImportPreview('Local PDF', checksum, records, diagnostics);
    } finally {
      await document.dispose();
    }
  }

  ImportPreview _epub(String filename, Uint8List bytes, String checksum) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.length > 1500 ||
        archive.files.fold<int>(0, (sum, file) => sum + file.size) >
            32 * 1024 * 1024)
      throw const FormatException(
        'EPUB expands beyond the supported size. Import smaller sections.',
      );
    final files = {
      for (final file in archive.files.where((f) => f.isFile)) file.name: file,
    };
    if (files.containsKey('META-INF/encryption.xml'))
      throw const FormatException(
        'Encrypted EPUB content is unsupported. Use an authorized text export.',
      );
    String read(String name) {
      final file = files[name];
      if (file == null) throw FormatException('Missing EPUB resource: $name');
      if (file.size > 4 * 1024 * 1024)
        throw const FormatException('An EPUB section is too large.');
      final output = _BoundedOutput(4 * 1024 * 1024);
      file.writeContent(output, freeMemory: false);
      final result = output.getBytes();
      if (getCrc32(result) != file.crc32)
        throw const FormatException('EPUB resource checksum failed.');
      return utf8.decode(result);
    }

    if (read('mimetype').trim() != 'application/epub+zip')
      throw const FormatException('Not an EPUB archive.');
    final container = XmlDocument.parse(read('META-INF/container.xml'));
    final path = container.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'rootfile')
        .first
        .getAttribute('full-path');
    if (path == null) throw const FormatException('No EPUB package document.');
    final package = XmlDocument.parse(read(path));
    String metadata(String name) => package.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == name)
        .map((e) => e.innerText.trim())
        .join(', ');
    final title = metadata('title'), author = metadata('creator');
    final manifest = {
      for (final item in package.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'item',
      ))
        item.getAttribute('id'): item.getAttribute('href'),
    };
    final spine = package.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'itemref')
        .toList();
    if (spine.length > 300)
      throw const FormatException(
        'Split EPUBs with more than 300 sections before importing.',
      );
    final records = <Map<String, dynamic>>[];
    var characters = 0;
    for (var i = 0; i < spine.length; i++) {
      final href = manifest[spine[i].getAttribute('idref')];
      if (href == null)
        throw const FormatException('Broken EPUB reading order.');
      final uri = Uri.parse(path).resolve(href);
      if (uri.hasScheme ||
          uri.path.startsWith('../') ||
          uri.path.startsWith('/'))
        throw const FormatException(
          'EPUB refers to an unsupported external resource.',
        );
      final chapter = XmlDocument.parse(read(uri.path));
      for (final element
          in chapter.descendants
              .whereType<XmlElement>()
              .where((e) => const {'script', 'style'}.contains(e.name.local))
              .toList()) {
        element.parent?.children.remove(element);
      }
      final text = chapter.descendants
          .whereType<XmlText>()
          .map((e) => e.value.trim())
          .where((s) => s.isNotEmpty)
          .join('\n');
      if (text.isEmpty) continue;
      characters += text.length;
      if (characters > 1000000)
        throw const FormatException(
          'Book text is too large; import smaller sections.',
        );
      records.add(
        _note(
          checksum,
          i,
          '${title.isEmpty ? filename : title} · Section ${i + 1}',
          '${title.isEmpty ? filename : title}${author.isEmpty ? '' : ' — $author'}',
          'Section ${i + 1} · ${uri.path}',
          text,
        ),
      );
    }
    if (records.isEmpty)
      throw const FormatException('No readable EPUB text found.');
    return ImportPreview('Local EPUB', checksum, records, []);
  }

  Map<String, dynamic> _note(
    String hash,
    int section,
    String title,
    String source,
    String reference,
    String body,
  ) => {
    'id': 'document-$hash-$section',
    'kind': 'note',
    'title': title,
    'source': source,
    'reference': reference,
    'body': body,
    'batch': hash,
    'sourceHash': hash,
    'rights': 'User-selected local document',
  };
}

class _BoundedOutput extends OutputMemoryStream {
  _BoundedOutput(this.limit);
  final int limit;
  void _check(int extra) {
    if (length + extra > limit)
      throw const FormatException(
        'EPUB decompressed data exceeds the supported size.',
      );
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
