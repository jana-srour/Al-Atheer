import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/archive_upload_service.dart';
import 'cover_image.dart';

class ArchiveCoverEditor extends StatefulWidget {
  final String? imageUrl;
  final Uint8List? previewBytes;
  final String uploadTitle;
  final ValueChanged<String?> onChanged;

  const ArchiveCoverEditor({
    super.key,
    required this.imageUrl,
    required this.uploadTitle,
    required this.onChanged,
    this.previewBytes,
  });

  @override
  State<ArchiveCoverEditor> createState() => _ArchiveCoverEditorState();
}

class _ArchiveCoverEditorState extends State<ArchiveCoverEditor> {
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final upload = await ArchiveUploadService.uploadFile(
        file: result.files.single,
        title: widget.uploadTitle.trim().isEmpty
            ? 'Al-Atheer cover image'
            : '${widget.uploadTitle.trim()} cover',
        category: 'Covers',
      );
      if (!upload.isSuccess || upload.directUrl == null) {
        throw StateError(upload.errorMessage ?? 'Cover image upload failed.');
      }
      if (!mounted) return;
      widget.onChanged(upload.directUrl);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeCover() {
    widget.onChanged(null);
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasCover =
        widget.imageUrl?.trim().isNotEmpty == true ||
        widget.previewBytes != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('صورة الغلاف', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child:
                    widget.previewBytes != null &&
                        (widget.imageUrl?.isEmpty ?? true)
                    ? Image.memory(widget.previewBytes!, fit: BoxFit.cover)
                    : CoverImage(
                        imageUrl: widget.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUpload,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_rounded),
                  label: Text(hasCover ? 'تغيير الغلاف' : 'رفع غلاف'),
                ),
                if (hasCover)
                  TextButton.icon(
                    onPressed: _isUploading ? null : _removeCover,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('إزالة الغلاف'),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                'تعذر رفع الغلاف: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
