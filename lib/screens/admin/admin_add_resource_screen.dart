import 'package:flutter/material.dart';
import 'admin_upload_widget.dart';

class AdminAddResourceScreen extends StatelessWidget {
  const AdminAddResourceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish New Resource'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AdminUploadWidget(
          onPublished: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

