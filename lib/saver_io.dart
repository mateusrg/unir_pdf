import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Salva os bytes do PDF unido em desktop/mobile usando o diálogo de
/// "Salvar como" do `file_picker` e gravando no disco.
Future<bool> saveMergedPdf(List<int> bytes, String suggestedName) async {
  final out = await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar PDF unido como',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (out == null || out.isEmpty) return false;
  await File(out).writeAsBytes(bytes);
  return true;
}