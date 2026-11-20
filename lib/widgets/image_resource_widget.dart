import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import 'archive_ingestion_modal.dart';
import 'editorial_photo.dart';
import 'resource_detail_sheet.dart';

class ImageResourceWidget extends StatelessWidget {
  final ResourceModel resource;

  const ImageResourceWidget({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    final imageUrl = resource.archiveUrl;
    final provider = Provider.of<ResourceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isReady = provider.isResourceReady(
      resource,
      delaySeconds: settings.archiveIngestionDelaySeconds,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ResourceDetailSheet.show(context, resource),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isReady)
              InkWell(
                onTap: () =>
                    ArchiveIngestionModal.show(context, resource: resource),
                child: const SizedBox(
                  width: double.infinity,
                  height: 220,
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
              )
            else if (imageUrl != null && imageUrl.isNotEmpty)
              EditorialPhoto(imageUrl: imageUrl, badgeText: 'صورة')
            else
              const SizedBox(
                height: 180,
                child: Center(child: Icon(Icons.image_not_supported_outlined)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resource.folderLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (resource.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(resource.description!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
