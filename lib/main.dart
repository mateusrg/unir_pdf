import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(const UnirPdfApp());
}

class UnirPdfApp extends StatelessWidget {
  const UnirPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unir PDFs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}