import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import 'archive_ingestion_modal.dart';
import 'audio_player_widget.dart';
import 'pdf_viewer_widget.dart';
import 'video_player_widget.dart';

class PostResourceWidget extends StatelessWidget {
  final ResourceModel resource;

  const PostResourceWidget({super.key, required this.resource});

  ResourceModel _asResource(ResourceAttachment attachment) {
    return ResourceModel(
      id: resource.id,
      title: attachment.fileName.isEmpty ? resource.title : attachment.fileName,
      type: attachment.type,
      archiveUrl: attachment.url,
      category: resource.category,
      createdAt: resource.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachments = resource.attachments;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (resource.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text(resource.description!),
            ],
            if (resource.textContent?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(
                resource.textContent!,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
            for (var index = 0; index < attachments.length; index++) ...[
              const SizedBox(height: 10),
              if (attachments[index].fileName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${index + 1}. ${attachments[index].fileName}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              switch (attachments[index].type) {
                'image' => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImage(context, attachments[index]),
                ),
                'audio' => AudioPlayerWidget(
                  resource: _asResource(attachments[index]),
                ),
                'video' => VideoPlayerWidget(
                  resource: _asResource(attachments[index]),
                ),
                'pdf' => PdfViewerWidget(
                  resource: _asResource(attachments[index]),
                ),
                _ => ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(attachments[index].fileName),
                  subtitle: Text(attachments[index].type),
                ),
              },
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, ResourceAttachment attachment) {
    final attachedResource = _asResource(attachment);
    final provider = Provider.of<ResourceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isReady = provider.isResourceReady(
      attachedResource,
      delaySeconds: settings.archiveIngestionDelaySeconds,
    );

    if (!isReady) {
      return InkWell(
        onTap: () =>
            ArchiveIngestionModal.show(context, resource: attachedResource),
        child: const SizedBox(
          height: 180,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, color: Color(0xFFF59E0B)),
                SizedBox(height: 8),
                Text('الصورة قيد التجهيز في الأرشيف'),
              ],
            ),
          ),
        ),
      );
    }

    return Image.network(
      attachment.url,
      width: double.infinity,
      height: 280,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, _, _) => const SizedBox(
        height: 160,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
