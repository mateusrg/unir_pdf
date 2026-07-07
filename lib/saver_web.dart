import 'dart:html' as html;
import 'dart:typed_data';

/// Salva os bytes do PDF unido em web disparando um download via Blob.
Future<bool> saveMergedPdf(List<int> bytes, String suggestedName) async {
  final typed = bytes is Uint8List ? bytes as Uint8List : Uint8List.fromList(bytes);
  final blob = html.Blob([typed], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', suggestedName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}