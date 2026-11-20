import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/archive_upload_service.dart';
import '../../widgets/archive_ingestion_modal.dart';

class VideoPlayerScreen extends StatefulWidget {
  final ResourceModel resource;

  const VideoPlayerScreen({super.key, required this.resource});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInit = false;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final archiveUrl = widget.resource.archiveUrl?.trim();
    if (archiveUrl == null || archiveUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    final resProv = Provider.of<ResourceProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isReady = resProv.isResourceReady(
      widget.resource,
      delaySeconds: settings.archiveIngestionDelaySeconds,
    );

    if (!isReady) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(archiveUrl),
      );
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFF59E0B),
          handleColor: const Color(0xFFF59E0B),
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade600,
        ),
      );

      if (mounted) {
        setState(() {
          _isInit = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Video Screen Player Init Error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final resProv = Provider.of<ResourceProvider>(context);
    final isFav = settings.isFavorite(widget.resource.id);
    final isReady = resProv.isResourceReady(
      widget.resource,
      delaySeconds: settings.archiveIngestionDelaySeconds,
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B132B)
          : const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.resource.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? radiantGold : Colors.white70,
            ),
            tooltip: 'حفظ في المفضلة',
            onPressed: () => settings.toggleFavorite(widget.resource.id),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            tooltip: 'مشاركة',
            onPressed: () {
              Share.share(
                '${widget.resource.title}\n${widget.resource.archiveUrl ?? ""}',
              );
            },
          ),
          if (widget.resource.archiveUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white70),
              tooltip: 'فتح في أرشيف الإنترنت',
              onPressed: () {
                final details = ArchiveUploadService.getDetailsUrlFromDirectUrl(
                  widget.resource.archiveUrl,
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Big Video Viewport on screen
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: _isInit && _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : _isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: radiantGold),
                                  SizedBox(height: 12),
                                  Text(
                                    'جاري تحميل البث المرئي...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      !isReady || !_hasError
                                          ? Icons.hourglass_top
                                          : Icons.error_outline,
                                      color: !isReady || !_hasError
                                          ? Colors.amber
                                          : Colors.redAccent,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.resource.archiveUrl
                                                  ?.trim()
                                                  .isEmpty ??
                                              true
                                          ? 'لا يتوفر رابط لهذا الفيديو'
                                          : !isReady
                                          ? 'الملف قيد التجهيز في خوادم أرشيف الإنترنت'
                                          : _hasError
                                          ? 'تعذر تحميل الفيديو'
                                          : 'جاري تجهيز مشغل الفيديو',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      !isReady
                                          ? 'متبقي حوالي ${widget.resource.formattedRemainingTime(delaySeconds: settings.archiveIngestionDelaySeconds)} دقيقة لاكتمال المعالجة.'
                                          : 'تحقق من اتصال الإنترنت ثم أعد المحاولة.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (widget.resource.archiveUrl
                                            ?.trim()
                                            .isNotEmpty ??
                                        false)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: radiantGold,
                                          foregroundColor: deepNavy,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.refresh),
                                        label: Text(
                                          isReady
                                              ? 'إعادة المحاولة'
                                              : 'فحص التجهيز وإعادة التشغيل',
                                        ),
                                        onPressed: !isReady
                                            ? () => ArchiveIngestionModal.show(
                                                context,
                                                resource: widget.resource,
                                                onReady: _initPlayer,
                                              )
                                            : _initPlayer,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Content Information & Details Below Video
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111D35)
                          : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge row
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFD97706),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.videocam,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.resource.folderLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'تاريخ النشر: ${widget.resource.formattedDate}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Title
                          Text(
                            widget.resource.title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description Box
                          if (widget.resource.description != null &&
                              widget.resource.description!.isNotEmpty) ...[
                            Text(
                              'تفاصيل الدرس المرئي:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: radiantGold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.resource.description!,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.7,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Archive Hosting Verification Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: radiantGold.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: radiantGold.withValues(alpha: 0.15),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_done,
                                    color: radiantGold,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مستضاف عبر شبكة أرشيف الإنترنت',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Archive.org Global CDN • بث مباشر عالي الدقة',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
