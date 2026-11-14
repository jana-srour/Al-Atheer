import 'package:flutter/material.dart';

class PdfReaderScreen extends StatelessWidget {
  final String url;
  final String title;

  const PdfReaderScreen({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Center(child: Text('PDF preview is available in the web app.')),
  );
}
