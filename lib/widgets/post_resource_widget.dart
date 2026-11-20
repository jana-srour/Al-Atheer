import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import 'archive_ingestion_modal.dart';
import 'audio_player_widget.dart';
import 'editorial_photo.dart';
import 'pdf_viewer_widget.dart';
import 'video_player_widget.dart';

class PostResourceWidget extends StatefulWidget {
  final ResourceModel resource;

  const PostResourceWidget({super.key, required this.resource});

  @override
  State<PostResourceWidget> createState() => _PostResourceWidgetState();
}

class _PostResourceWidgetState extends State<PostResourceWidget> {
  late PageController _photoController;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _photoController = PageController();
  }

  @override
  void didUpdateWidget(covariant PostResourceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.id != widget.resource.id ||
        oldWidget.resource.coverUrl != widget.resource.coverUrl ||
        _photoAttachmentsChanged(oldWidget.resource, widget.resource)) {
      _currentPhotoIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _photoController.hasClients) {
          _photoController.jumpToPage(0);
        }
      });
    }
  }

  bool _photoAttachmentsChanged(ResourceModel previous, ResourceModel current) {
    final oldPhotos = previous.attachments.where(
      (attachment) => attachment.type == 'image',
    );
    final newPhotos = current.attachments.where(
      (attachment) => attachment.type == 'image',
    );
    if (oldPhotos.length != newPhotos.length) return true;
    for (var index = 0; index < oldPhotos.length; index++) {
      if (oldPhotos.elementAt(index).url != newPhotos.elementAt(index).url) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  ResourceModel _asResource(ResourceAttachment attachment) {
    return ResourceModel(
      id: widget.resource.id,
      title: attachment.fileName.isEmpty
          ? widget.resource.title
          : attachment.fileName,
      type: attachment.type,
      archiveUrl: attachment.url,
      category: widget.resource.category,
      subfolder: widget.resource.subfolder,
      createdAt: widget.resource.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final attachments = resource.attachments;
    final photoAttachments = attachments
        .where((attachment) => attachment.type == 'image')
        .toList();
    final photoPages = <ResourceAttachment>[];
    final seenPhotoUrls = <String>{};

    void addPhoto(ResourceAttachment attachment) {
      if (seenPhotoUrls.add(attachment.url)) photoPages.add(attachment);
    }

    final coverUrl = resource.coverUrl;
    if (coverUrl != null) {
      final attachedCover = photoAttachments.where(
        (attachment) => attachment.url == coverUrl,
      );
      addPhoto(
        attachedCover.isNotEmpty
            ? attachedCover.first
            : ResourceAttachment(type: 'image', url: coverUrl, fileName: ''),
      );
    }
    for (final attachment in photoAttachments) {
      addPhoto(attachment);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoPages.isNotEmpty) ...[
              _buildPhotoGallery(context, photoPages),
              const SizedBox(height: 14),
            ],
            Text(
              resource.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              resource.folderLabel,
              style: Theme.of(context).textTheme.labelSmall,
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
            for (var index = 0; index < attachments.length; index++)
              if (attachments[index].type != 'image') ...[
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

  Widget _buildPhotoGallery(
    BuildContext context,
    List<ResourceAttachment> photos,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 0.62)
            .clamp(220.0, 420.0)
            .toDouble();
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: height,
                child: PageView.builder(
                  key: ValueKey(widget.resource.id),
                  controller: _photoController,
                  itemCount: photos.length,
                  onPageChanged: (index) {
                    if (mounted) setState(() => _currentPhotoIndex = index);
                  },
                  itemBuilder: (context, index) => _buildImage(
                    context,
                    photos[index],
                    photos,
                    index,
                    photos.length,
                  ),
                ),
              ),
            ),
            if (photos.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (var index = 0; index < photos.length; index++)
                    Semantics(
                      button: true,
                      selected: index == _currentPhotoIndex,
                      label: 'الصورة ${index + 1} من ${photos.length}',
                      child: InkWell(
                        onTap: () => _photoController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: index == _currentPhotoIndex ? 18 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == _currentPhotoIndex
                                    ? const Color(0xFFF59E0B)
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    ResourceAttachment attachment,
    List<ResourceAttachment> photos,
    int index,
    int total,
  ) {
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
        child: const SizedBox.expand(
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

    return EditorialPhoto(
      imageUrl: attachment.url,
      badgeText: '${index + 1} / $total',
      galleryImages: photos.map((photo) => photo.url).toList(),
      initialIndex: index,
    );
  }
}
