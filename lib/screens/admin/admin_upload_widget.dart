import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/archive_upload_service.dart';
import '../../widgets/archive_cover_editor.dart';

class AdminUploadWidget extends StatefulWidget {
  final VoidCallback? onPublished;

  const AdminUploadWidget({super.key, this.onPublished});

  @override
  State<AdminUploadWidget> createState() => _AdminUploadWidgetState();
}

class _AdminUploadWidgetState extends State<AdminUploadWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _textContentController = TextEditingController();

  List<PlatformFile> _selectedFiles = [];
  String? _coverImageUrl;
  bool _coverImageHidden = false;
  String _resourceType = 'pdf';
  String _selectedCategory = '';
  String _selectedSubfolder = '';

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  bool _hasArchiveKeys = false;
  bool get _requiresArchiveKeys =>
      _resourceType != 'text' &&
      (_resourceType != 'post' || _selectedFiles.isNotEmpty);

  PlatformFile? get _firstSelectedImage {
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    for (final file in _selectedFiles) {
      final extension =
          file.extension ?? file.name.split('.').last.toLowerCase();
      if (imageExtensions.contains(extension.toLowerCase())) return file;
    }
    return null;
  }

  // Active Ingestion Tracker State for newly uploaded item
  ResourceModel? _lastUploadedResource;
  Timer? _countdownTimer;
  int _countdownSecondsRemaining = 120;
  bool _isTestingReadiness = false;
  String? _readinessFeedback;

  @override
  void initState() {
    super.initState();
    _checkArchiveKeys();
  }

  Future<void> _checkArchiveKeys() async {
    final hasKeys = await ArchiveUploadService.hasCredentials();
    if (mounted) setState(() => _hasArchiveKeys = hasKeys);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  void _startIngestionCountdown(ResourceModel resource, int totalDelaySeconds) {
    _countdownTimer?.cancel();
    setState(() {
      _lastUploadedResource = resource;
      _countdownSecondsRemaining = totalDelaySeconds;
      _readinessFeedback = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSecondsRemaining > 0) {
          _countdownSecondsRemaining--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  Future<void> _testLastUploadReadiness() async {
    if (_lastUploadedResource?.archiveUrl == null) return;
    setState(() {
      _isTestingReadiness = true;
      _readinessFeedback = null;
    });

    final resProv = Provider.of<ResourceProvider>(context, listen: false);
    final isReady = await resProv.probeResourceReadiness(
      _lastUploadedResource!,
    );

    if (!mounted) return;
    setState(() {
      _isTestingReadiness = false;
      if (isReady) {
        _countdownSecondsRemaining = 0;
        _countdownTimer?.cancel();
        _readinessFeedback = '🎉 أصبح الملف متاحاً بالكامل في الأرشيف!';
      } else {
        _readinessFeedback = '⏳ لا يزال الأرشيف يعالج الفهارس، انتظر لحظات.';
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _pickFile() async {
    final extensions = switch (_resourceType) {
      'pdf' => ['pdf'],
      'audio' => ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      'video' => ['mp4', 'mov', 'mkv', 'webm'],
      'image' => ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      'post' => [
        'pdf',
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'mkv',
        'webm',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
      ],
      _ => <String>[],
    };

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: _resourceType == 'post',
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = _resourceType == 'post'
            ? [..._selectedFiles, ...result.files]
            : result.files;
        if (_titleController.text.trim().isEmpty) {
          final rawName = result.files.first.name;
          final lastDot = rawName.lastIndexOf('.');
          final nameWithoutExt = lastDot != -1
              ? rawName.substring(0, lastDot)
              : rawName;
          _titleController.text = nameWithoutExt.replaceAll('_', ' ');
        }
      });
    }
  }

  void _showCredentialsDialog() {
    final accessCtrl = TextEditingController();
    final secretCtrl = TextEditingController();

    ArchiveUploadService.getCredentials().then((creds) {
      if (creds != null) {
        accessCtrl.text = creds['accessKey'] ?? '';
        secretCtrl.text = creds['secretKey'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Archive.org S3 Keys', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Internet Archive S3 Access & Secret Keys to upload directly from the app to archive.org.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://archive.org/account/s3.php'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Get free S3 Keys from archive.org/account/s3.php',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: accessCtrl,
                decoration: const InputDecoration(
                  labelText: 'S3 Access Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'S3 Secret Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (accessCtrl.text.trim().isNotEmpty &&
                  secretCtrl.text.trim().isNotEmpty) {
                try {
                  await ArchiveUploadService.saveCredentials(
                    accessKey: accessCtrl.text.trim(),
                    secretKey: secretCtrl.text.trim(),
                  );
                  await _checkArchiveKeys();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Archive.org S3 credentials saved!'),
                        backgroundColor: Color(0xFF0F172A),
                      ),
                    );
                  }
                } catch (error) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Could not save credentials: $error'),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save Keys'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: catController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Hadith, Seerah',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCat = catController.text.trim();
              if (newCat.isNotEmpty) {
                var added = false;
                try {
                  await Supabase.instance.client.from('categories').insert({
                    'name': newCat,
                  });
                  added = true;
                  if (mounted) {
                    await Provider.of<ResourceProvider>(
                      context,
                      listen: false,
                    ).fetchCategories();
                    setState(() => _selectedCategory = newCat);
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر إضافة التصنيف: $error')),
                    );
                  }
                }
                if (added && ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePublish() async {
    if (!_formKey.currentState!.validate()) return;

    final textContent = _textContentController.text.trim();
    final hasArchiveFiles = _selectedFiles.isNotEmpty;
    if (_resourceType != 'text' &&
        _resourceType != 'post' &&
        _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file to upload.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_resourceType == 'post' &&
        _selectedFiles.isEmpty &&
        textContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف نصاً أو ملفاً واحداً على الأقل للمنشور.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_requiresArchiveKeys && !_hasArchiveKeys) {
      _showCredentialsDialog();
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final delaySeconds = settings.archiveIngestionDelaySeconds;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Preparing media package...';
      _lastUploadedResource = null;
    });

    try {
      String? archiveDirectUrl;
      final uploadedAttachments = <Map<String, dynamic>>[];

      for (var index = 0; index < _selectedFiles.length; index++) {
        final file = _selectedFiles[index];
        setState(() {
          _uploadStatus =
              'Uploading ${index + 1}/${_selectedFiles.length} to Archive.org...';
        });

        final uploadResult = await ArchiveUploadService.uploadFile(
          file: file,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory,
          onProgress: (progress, sent, total) {
            if (!mounted) return;
            final overallProgress = (index + progress) / _selectedFiles.length;
            setState(() {
              _uploadProgress = overallProgress * 0.9;
              _uploadStatus =
                  'Uploading ${index + 1}/${_selectedFiles.length} (${(progress * 100).toInt()}% • ${_formatFileSize(sent)} / ${_formatFileSize(total)})';
            });
          },
        );

        if (!uploadResult.isSuccess || uploadResult.directUrl == null) {
          throw Exception(
            'Could not upload ${file.name}: ${uploadResult.errorMessage ?? 'Upload failed'}',
          );
        }

        final mediaInfo = ArchiveUploadService.getMediaTypeInfo(
          file.extension ?? '',
        );
        uploadedAttachments.add({
          'type': mediaInfo['appType'],
          'url': uploadResult.directUrl,
          'file_name': file.name,
        });
        archiveDirectUrl ??= uploadResult.directUrl;
      }

      // 2. Register record in Supabase Database
      setState(() {
        _uploadProgress = 0.95;
        _uploadStatus = 'Saving record in Supabase database...';
      });

      Map<String, dynamic>? firstImageAttachment;
      for (final attachment in uploadedAttachments) {
        if (attachment['type'] == 'image') {
          firstImageAttachment = attachment;
          break;
        }
      }
      final firstImageUrl = firstImageAttachment == null
          ? null
          : firstImageAttachment['url']?.toString();
      final coverImageUrl = _resourceType == 'post' && !_coverImageHidden
          ? _coverImageUrl ?? firstImageUrl
          : null;

      final insertResponse = await Supabase.instance.client
          .from('resources')
          .insert({
            'title': _titleController.text.trim(),
            'description': _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            'type': _resourceType,
            'archive_url': archiveDirectUrl,
            'text_content':
                (_resourceType == 'text' || _resourceType == 'post') &&
                    textContent.isNotEmpty
                ? textContent
                : null,
            'attachments': _resourceType == 'post'
                ? uploadedAttachments
                : <Map<String, dynamic>>[],
            'cover_image_url': coverImageUrl,
            'cover_image_hidden': _resourceType == 'post' && _coverImageHidden,
            'category': _selectedCategory,
            'subfolder': _selectedSubfolder,
          })
          .select()
          .single();

      final newlyCreated = ResourceModel.fromMap(insertResponse);

      // 3. Refresh ResourceProvider
      if (mounted) {
        await Provider.of<ResourceProvider>(
          context,
          listen: false,
        ).fetchResources();
      }

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadStatus = 'Successfully Published!';
        _selectedFiles = [];
        _coverImageUrl = null;
        _coverImageHidden = false;
      });

      _titleController.clear();
      _descController.clear();
      _textContentController.clear();

      // Start Ingestion Countdown Tracking
      if (hasArchiveFiles) {
        _startIngestionCountdown(newlyCreated, delaySeconds);
      }

      widget.onPublished?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _resourceType == 'text'
                        ? 'تم نشر الفائدة بنجاح!'
                        : _resourceType == 'post' && !hasArchiveFiles
                        ? 'تم نشر المنشور بنجاح!'
                        : 'تم الرفع لأرشيف الإنترنت! بدأ مؤقت التجهيز ($delaySeconds ثانية).',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Publish Error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Upload Failed';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepEmerald = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);

    final resourceProvider = Provider.of<ResourceProvider>(context);
    final categories = resourceProvider.categories;

    if (categories.isNotEmpty && !categories.contains(_selectedCategory)) {
      _selectedCategory = categories.first;
    }

    final delaySeconds = settings.archiveIngestionDelaySeconds;

    return Column(
      children: [
        // Live Ingestion Countdown Center Banner (shown right after publishing media)
        if (_lastUploadedResource != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F7)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _countdownSecondsRemaining > 0
                    ? radiantGold
                    : radiantGold,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: radiantGold.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _countdownSecondsRemaining > 0
                              ? Icons.hourglass_top_rounded
                              : Icons.check_circle_rounded,
                          color: _countdownSecondsRemaining > 0
                              ? radiantGold
                              : radiantGold,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _countdownSecondsRemaining > 0
                              ? 'مركز تجهيز الأرشيف • مؤقت الفهرسة'
                              : 'اكتملت الفهرسة • متاح في التطبيق الآن',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() => _lastUploadedResource = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Timer Visualizer Row
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: delaySeconds > 0
                                ? (1.0 -
                                      (_countdownSecondsRemaining /
                                          delaySeconds))
                                : 1.0,
                            strokeWidth: 4,
                            backgroundColor: radiantGold.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _countdownSecondsRemaining > 0
                                  ? radiantGold
                                  : radiantGold,
                            ),
                          ),
                          Text(
                            _formatRemainingTime(_countdownSecondsRemaining),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lastUploadedResource!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _countdownSecondsRemaining > 0
                                ? 'يقوم أرشيف الإنترنت الآن بفهرسة وتوزيع الملف على شبكة الـ CDN. سيظهر للمستخدمين تلقائياً وبدون خطأ (غير موجود) بعد انتهاء العداد.'
                                : 'الملف جاهز ومتاح للجميع للقراءة والاستماع داخل التطبيق.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_readinessFeedback != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _readinessFeedback!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _readinessFeedback!.contains('🎉')
                          ? radiantGold
                          : Colors.amber.shade900,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepEmerald,
                          foregroundColor: radiantGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: radiantGold),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: _isTestingReadiness
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: radiantGold,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'فحص الجاهزية الآن',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: _isTestingReadiness
                            ? null
                            : _testLastUploadReadiness,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_lastUploadedResource?.archiveUrl != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: radiantGold.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                        ),
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: radiantGold,
                        ),
                        label: const Text(
                          'معاينة في Archive',
                          style: TextStyle(fontSize: 11, color: radiantGold),
                        ),
                        onPressed: () {
                          final details =
                              ArchiveUploadService.getDetailsUrlFromDirectUrl(
                                _lastUploadedResource!.archiveUrl,
                              );
                          if (details != null) {
                            launchUrl(
                              Uri.parse(details),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Main Studio Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: radiantGold.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF8FAFC)],
              ),
            ),
            padding: const EdgeInsets.all(22.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: deepEmerald.withValues(alpha: 0.15),
                              border: Border.all(
                                color: radiantGold,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: radiantGold,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'استوديو النشر الرقمي',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'رفع مباشر ومؤتمت إلى أرشيف الإنترنت',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          _hasArchiveKeys ? Icons.vpn_key : Icons.vpn_key_off,
                          color: _hasArchiveKeys
                              ? radiantGold
                              : Colors.redAccent,
                        ),
                        tooltip: 'مفاتيح Archive S3',
                        onPressed: _showCredentialsDialog,
                      ),
                    ],
                  ),

                  // S3 Key Banner if missing
                  if (_requiresArchiveKeys && !_hasArchiveKeys) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'يرجى ضبط مفاتيح Archive S3 لتمكين الرفع المباشر للأرشيف.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showCredentialsDialog,
                            child: const Text(
                              'إعداد',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Resource Type Selector
                  const Text(
                    'نوع المادة المراد نشرها',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTypeChip('pdf', 'كتاب PDF', Icons.picture_as_pdf),
                        const SizedBox(width: 8),
                        _buildTypeChip('audio', 'تسجيل صوتي', Icons.audiotrack),
                        const SizedBox(width: 8),
                        _buildTypeChip(
                          'video',
                          'مرئي / درس مصور',
                          Icons.videocam,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeChip('image', 'صورة', Icons.image_outlined),
                        const SizedBox(width: 8),
                        _buildTypeChip(
                          'text',
                          'اقتباس / فائدة',
                          Icons.format_quote,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeChip(
                          'post',
                          'منشور متعدد الوسائط',
                          Icons.post_add,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Drop zone for Media Files
                  if (_resourceType != 'text') ...[
                    InkWell(
                      onTap: _isUploading ? null : _pickFile,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFiles.isEmpty
                                ? radiantGold.withValues(alpha: 0.4)
                                : radiantGold,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFiles.isEmpty
                                  ? Icons.file_upload_outlined
                                  : Icons.check_circle_outline,
                              size: 40,
                              color: radiantGold,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedFiles.isEmpty
                                  ? _resourceType == 'post'
                                        ? 'اضغط لإضافة صور أو ملفات للمنشور'
                                        : 'اضغط لاختيار ملف ${_resourceType.toUpperCase()}'
                                  : _resourceType == 'post'
                                  ? 'تم اختيار ${_selectedFiles.length} ملف • اضغط لإضافة المزيد'
                                  : _selectedFiles.first.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedFiles.isEmpty
                                  ? 'الصيغ المدعومة: ${switch (_resourceType) {
                                      'pdf' => 'PDF',
                                      'audio' => 'MP3, M4A, WAV, AAC, OGG',
                                      'video' => 'MP4, MKV, MOV, WEBM',
                                      'image' => 'JPG, PNG, GIF, WEBP',
                                      _ => 'PDF, صوت، فيديو وصور',
                                    }}'
                                  : _resourceType == 'post'
                                  ? 'اختر صوراً أو ملفات إضافية كلما ضغطت هنا'
                                  : '${_formatFileSize(_selectedFiles.first.size)} • اضغط للاستبدال',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (
                            var index = 0;
                            index < _selectedFiles.length;
                            index++
                          )
                            InputChip(
                              label: Text(
                                '${_selectedFiles[index].name} (${_formatFileSize(_selectedFiles[index].size)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: _isUploading
                                  ? null
                                  : () => setState(
                                      () => _selectedFiles.removeAt(index),
                                    ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'عنوان المادة *',
                      hintText: 'مثال: شرح كتاب التوحيد - الدرس الأول',
                      prefixIcon: const Icon(Icons.title, color: radiantGold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'عنوان المادة مطلوب'
                        : null,
                  ),

                  const SizedBox(height: 14),

                  // Category Selector with quick add
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: categories.contains(_selectedCategory)
                              ? _selectedCategory
                              : null,
                          decoration: InputDecoration(
                            labelText: 'التصنيف *',
                            prefixIcon: const Icon(
                              Icons.category,
                              color: radiantGold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: categories
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'أضف تصنيفاً أولاً' : null,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategory = val;
                                _selectedSubfolder = '';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: deepEmerald,
                        ),
                        icon: const Icon(Icons.add, color: radiantGold),
                        tooltip: 'تصنيف جديد',
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),

                  if (resourceProvider
                      .subfoldersForCategory(_selectedCategory)
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSubfolder,
                      decoration: InputDecoration(
                        labelText: 'المجلد الفرعي (اختياري)',
                        prefixIcon: const Icon(
                          Icons.folder_open_outlined,
                          color: radiantGold,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('المجلد الرئيسي'),
                        ),
                        ...resourceProvider
                            .subfoldersForCategory(_selectedCategory)
                            .map(
                              (subfolder) => DropdownMenuItem(
                                value: subfolder,
                                child: Text(subfolder),
                              ),
                            ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedSubfolder = value ?? ''),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Quote Content if Text type
                  if (_resourceType == 'text' || _resourceType == 'post') ...[
                    TextFormField(
                      controller: _textContentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: _resourceType == 'text'
                            ? 'نص الفائدة أو الاقتباس *'
                            : 'نص المنشور (اختياري)',
                        hintText: _resourceType == 'text'
                            ? 'اكتب نص الفائدة العلمية أو الحديث هنا...'
                            : 'اكتب نصاً يرافق الملفات المرفقة...',
                        prefixIcon: const Icon(
                          Icons.format_quote,
                          color: radiantGold,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (val) =>
                          _resourceType == 'text' &&
                              (val == null || val.trim().isEmpty)
                          ? 'نص الفائدة مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Description Field
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'نبذة أو وصف مختصر (اختياري)',
                      hintText: 'موجز عن المحتوى والمؤلف والفوائد المستنبطة',
                      prefixIcon: const Icon(
                        Icons.description,
                        color: radiantGold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  if (_resourceType == 'post') ...[
                    const SizedBox(height: 14),
                    ArchiveCoverEditor(
                      imageUrl: _coverImageUrl,
                      previewBytes: _coverImageHidden
                          ? null
                          : _firstSelectedImage?.bytes,
                      uploadTitle: _titleController.text,
                      onChanged: (url) => setState(() {
                        _coverImageUrl = url;
                        _coverImageHidden = url == null;
                      }),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'أول صورة في مرفقات المنشور تُستخدم غلافاً تلقائياً، '
                      'ويمكنك رفع غلاف مستقل أو إزالة الغلاف.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Upload Progress Section
                  if (_isUploading) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _uploadStatus,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: radiantGold,
                                ),
                              ),
                            ),
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: radiantGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: radiantGold.withValues(alpha: 0.2),
                            color: radiantGold,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deepEmerald,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: radiantGold, width: 1),
                        ),
                      ),
                      onPressed: _isUploading ? null : _handlePublish,
                      child: _isUploading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: radiantGold,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'جاري الرفع والنشر...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _resourceType == 'text' ||
                                          (_resourceType == 'post' &&
                                              _selectedFiles.isEmpty)
                                      ? Icons.post_add
                                      : Icons.cloud_upload,
                                  color: radiantGold,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _resourceType == 'text'
                                      ? 'نشر الفائدة الآن'
                                      : _resourceType == 'post'
                                      ? 'نشر المنشور والملفات'
                                      : 'رفع ونشر المادة مع مؤقت التجهيز',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Ingestion hint
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مؤقت التجهيز مضبوط على $delaySeconds ثانية لتجنب ظهور خطأ (غير موجود).',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRemainingTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _resourceType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radiantGold = Color(0xFFF59E0B);
    const deepEmerald = Color(0xFF0F172A);

    return ChoiceChip(
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _resourceType = type;
            _selectedFiles = [];
            if (type != 'post') {
              _coverImageUrl = null;
              _coverImageHidden = false;
            }
          });
        }
      },
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? radiantGold : (isDark ? Colors.grey : deepEmerald),
      ),
      label: Text(label),
      selectedColor: deepEmerald,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey.shade300 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? radiantGold
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
    );
  }
}
