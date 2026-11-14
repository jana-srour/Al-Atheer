import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

class PdfReaderScreen extends StatelessWidget {
  final String url;
  final String title;

  const PdfReaderScreen({super.key, required this.url, required this.title});

  void _configureFrame(Object element) {
    final frame = element as JSObject;
    frame
      ..setProperty('src'.toJS, url.toJS)
      ..setProperty('title'.toJS, title.toJS)
      ..setProperty('style'.toJS, 'width:100%;height:100%;border:0;'.toJS);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _configureFrame,
    ),
  );
}
