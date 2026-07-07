// Exporta a implementação correta conforme a plataforma.
//
// Em web (`dart.library.html`), o `file_reader_web.dart` assume; caso
// contrário (desktop/mobile), `file_reader_io.dart`.
export 'file_reader_io.dart' if (dart.library.html) 'file_reader_web.dart';