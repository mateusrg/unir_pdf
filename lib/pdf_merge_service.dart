import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Resultado da operação de união.
class MergeResult {
  final String outputPath;
  final int fileCount;
  final int pageCount;

  const MergeResult({
    required this.outputPath,
    required this.fileCount,
    required this.pageCount,
  });
}

/// Serviço responsável por unir arquivos PDF.
///
/// Usa o pacote `syncfusion_flutter_pdf` (puro Dart). Para preservar o
/// tamanho e a orientação de cada página de origem, copiamos as páginas
/// por meio de `PdfTemplate` dentro de seções próprias do documento final.
class PdfMergeService {
  /// Une os [files] na ordem recebida e salva em [outputPath].
  ///
  /// Lança [Exception] quando algum arquivo não pode ser lido ou não é PDF.
  static Future<MergeResult> merge({
    required List<File> files,
    required String outputPath,
  }) async {
    if (files.isEmpty) {
      throw Exception('Nenhum arquivo selecionado.');
    }

    final finalDoc = PdfDocument();
    int totalPages = 0;

    try {
      for (final file in files) {
        if (!file.existsSync()) {
          throw Exception('Arquivo não encontrado: ${file.path}');
        }
        final doc = PdfDocument(inputBytes: await file.readAsBytes());
        try {
          for (var i = 0; i < doc.pages.count; i++) {
            final sourcePage = doc.pages[i];
            final template = sourcePage.createTemplate();

            final section = finalDoc.sections!.add();
            section.pageSettings.size = template.size;
            section.pageSettings.margins.all = 0;

            final newPage = section.pages.add();
            newPage.graphics.drawPdfTemplate(template, Offset.zero, template.size);
            totalPages++;
          }
        } finally {
          doc.dispose();
        }
      }

      final bytes = finalDoc.saveSync();
      await File(outputPath).writeAsBytes(bytes);

      return MergeResult(
        outputPath: outputPath,
        fileCount: files.length,
        pageCount: totalPages,
      );
    } finally {
      finalDoc.dispose();
    }
  }

  /// Ordena por nome de arquivo (auxiliar).
  static List<File> sortByName(List<File> files, {bool ascending = true}) {
    final copy = List<File>.from(files);
    copy.sort((a, b) {
      final cmp = p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase());
      return ascending ? cmp : -cmp;
    });
    return copy;
  }
}