import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import 'file_reader.dart';

/// Representação unificada de um arquivo PDF selecionado, funcionando
/// tanto em desktop/mobile (via path) quanto em web (via bytes em memória).
class PdfSource {
  final String name;
  final int? sizeBytes;
  final Future<List<int>> Function() _read;

  PdfSource({
    required this.name,
    required Future<List<int>> Function() read,
    this.sizeBytes,
  }) : _read = read;

  Future<List<int>> readBytes() => _read();

  String get sizeLabel {
    final size = sizeBytes;
    if (size == null) return '—';
    final kb = size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  /// Cria a partir de um `PlatformFile` retornado pelo `file_picker`.
  factory PdfSource.fromPicker(PlatformFile pf) {
    if (kIsWeb) {
      final bytes = pf.bytes;
      if (bytes == null) {
        throw StateError(
          'Em web, file_picker deve ser chamado com withData: true.',
        );
      }
      return PdfSource(
        name: pf.name,
        sizeBytes: bytes.length,
        read: () async => bytes,
      );
    }
    final path = pf.path;
    if (path == null) {
      throw StateError('Plataforma sem caminho de arquivo disponível.');
    }
    return PdfSource(
      name: p.basename(path),
      sizeBytes: pf.size > 0 ? pf.size : fileSizeFromPath(path),
      read: () async => await readFileFromPath(path),
    );
  }

  /// Cria a partir de um `XFile` (geralmente do `desktop_drop`).
  factory PdfSource.fromXFile(XFile xfile) {
    return PdfSource(
      name: xfile.name,
      sizeBytes: null,
      read: () async => await xfile.readAsBytes(),
    );
  }
}