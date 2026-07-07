// Exporta o saver correto conforme a plataforma.
export 'saver_io.dart' if (dart.library.html) 'saver_web.dart';