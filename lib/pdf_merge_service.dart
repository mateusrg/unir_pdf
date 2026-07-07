import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_source.dart';

/// Resultado da operação de união.
class MergeResult {
  final int fileCount;
  final int pageCount;
  final List<int> bytes;

  const MergeResult({
    required this.fileCount,
    required this.pageCount,
    required this.bytes,
  });
}

/// Serviço responsável por unir arquivos PDF.
///
/// Usa o pacote `syncfusion_flutter_pdf` (puro Dart). Para preservar o
/// tamanho e a orientação de cada página de origem, copiamos as páginas
/// por meio de `PdfTemplate` dentro de seções próprias do documento final.
class PdfMergeService {
  /// Une os [files] na ordem recebida e devolve os bytes resultantes.
  ///
  /// Lança [Exception] quando algum arquivo não pode ser lido ou não é PDF.
  static Future<MergeResult> merge(List<PdfSource> files) async {
    if (files.isEmpty) {
      throw Exception('Nenhum arquivo selecionado.');
    }

    final finalDoc = PdfDocument();
    int totalPages = 0;

    try {
      for (final source in files) {
        final bytes = await source.readBytes();
        final doc = PdfDocument(inputBytes: bytes);
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
      return MergeResult(
        fileCount: files.length,
        pageCount: totalPages,
        bytes: bytes,
      );
    } finally {
      finalDoc.dispose();
    }
  }

  /// Sugere um nome de arquivo de saída com timestamp.
  static String defaultOutputName() {
    final stamp = DateTime.now().toLocal().toIso8601String().replaceAll(
      RegExp(r'[:T.]'),
      '-',
    ).substring(0, 19);
    return 'unidos_$stamp.pdf';
  }
}