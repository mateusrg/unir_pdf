import 'dart:typed_data';

/// Stub para web: nunca deve ser chamado (kIsWeb garante antes).
Future<Uint8List> readFileFromPath(String path) async =>
    throw UnsupportedError('Leitura por path não suportada na web.');

int fileSizeFromPath(String path) =>
    throw UnsupportedError('Leitura por path não suportada na web.');