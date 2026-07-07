import 'dart:io';
import 'dart:typed_data';

/// Lê bytes de um arquivo pelo caminho (apenas desktop/mobile).
Future<Uint8List> readFileFromPath(String path) =>
    File(path).readAsBytes();

/// Retorna o tamanho em bytes de um arquivo (apenas desktop/mobile).
int fileSizeFromPath(String path) => File(path).lengthSync();