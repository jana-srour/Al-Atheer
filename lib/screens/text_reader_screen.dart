import 'package:flutter/material.dart';
import '../models/resource_model.dart';

class TextReaderScreen extends StatelessWidget {
  final ResourceModel resource;

  const TextReaderScreen({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    final text = resource.textContent?.trim().isNotEmpty == true
        ? resource.textContent!
        : resource.description ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(resource.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  resource.category,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SelectableText(
                  text,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.9,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
