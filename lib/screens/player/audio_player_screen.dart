import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/archive_ingestion_modal.dart';

class AudioPlayerScreen extends StatefulWidget {
  final ResourceModel resource;

  const AudioPlayerScreen({super.key, required this.resource});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInit = false;
  bool _isLoading = true;
  bool _hasError = false;
  double _speed = 1.0;
  bool _isLooping = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _audioPlayer = AudioPlayer();
    _setupAudioListeners();
    _initAudio();
  }

  void _setupAudioListeners() {
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _initAudio() async {
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
      await _audioPlayer.setUrl(archiveUrl);
      if (mounted) {
        setState(() {
          _isInit = true;
          _isLoading = false;
        });
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Audio Screen Player Init Error: $e');
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
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _audioPlayer.seek(clamped);
  }

  void _cycleSpeed() {
    double nextSpeed = 1.0;
    if (_speed == 1.0) {
      nextSpeed = 1.25;
    } else if (_speed == 1.25) {
      nextSpeed = 1.5;
    } else if (_speed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }
    setState(() => _speed = nextSpeed);
    _audioPlayer.setSpeed(nextSpeed);
  }

  void _toggleLoop() {
    setState(() => _isLooping = !_isLooping);
    _audioPlayer.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$h$m:$s';
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
          ? const Color(0xFF0A1128)
          : const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'مشغل الصوتيات الرقمي',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Illuminated Big Album Disc Artwork
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow = _isPlaying ? _pulseController.value * 12.0 : 4.0;
                  return Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                          Color(0xFF020617),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: radiantGold.withValues(
                            alpha: _isPlaying ? 0.35 : 0.15,
                          ),
                          blurRadius: 28 + glow,
                          spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: radiantGold.withValues(alpha: 0.8),
                        width: 2.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Decorative vinyl rings
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: radiantGold.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        // Center gold medallion
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: radiantGold.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.headphones_rounded,
                            color: deepNavy,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),

              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.resource.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                widget.resource.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'دار الأثير للنشر • مسموع عالي الجودة',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),

              // Animated Soundwave Visualizer Bar
              if (_isPlaying) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(12, (index) {
                    final factor = (index % 3 == 0)
                        ? _pulseController.value
                        : ((index % 2 == 0)
                              ? (1.0 - _pulseController.value)
                              : (_pulseController.value * 0.7 + 0.3));
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: 4,
                      height: 10 + (factor * 26),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFFD97706), Color(0xFFFDE68A)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
              ],

              // Ingestion warning if not ready
              if (!isReady || _hasError) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        !isReady ? Icons.hourglass_top : Icons.error_outline,
                        color: !isReady ? Colors.amber : Colors.redAccent,
                        size: 30,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.resource.archiveUrl?.trim().isEmpty ?? true
                            ? 'لا يتوفر رابط لهذا التسجيل'
                            : !isReady
                            ? 'الملف الصوتي قيد الفهرسة في أرشيف الإنترنت'
                            : 'تعذر تحميل التسجيل الصوتي',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !isReady
                            ? 'متبقي حوالي ${widget.resource.formattedRemainingTime(delaySeconds: settings.archiveIngestionDelaySeconds)} دقيقة لاكتمال البث.'
                            : 'تحقق من اتصال الإنترنت ثم أعد المحاولة.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (widget.resource.archiveUrl?.trim().isNotEmpty ??
                          false)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: radiantGold,
                            foregroundColor: deepNavy,
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(
                            !isReady
                                ? 'فحص الجاهزية والتشغيل'
                                : 'إعادة المحاولة',
                          ),
                          onPressed: !isReady
                              ? () => ArchiveIngestionModal.show(
                                  context,
                                  resource: widget.resource,
                                  onReady: _initAudio,
                                )
                              : _initAudio,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Progress Seek Bar
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  activeTrackColor: radiantGold,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  thumbColor: radiantGold,
                  overlayColor: radiantGold.withValues(alpha: 0.25),
                ),
                child: Slider(
                  min: 0.0,
                  max: _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                  value: _position.inSeconds
                      .clamp(
                        0,
                        _duration.inSeconds > 0 ? _duration.inSeconds : 1,
                      )
                      .toDouble(),
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(seconds: val.toInt()));
                  },
                ),
              ),

              // Time labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Audio Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Loop button
                  IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: _isLooping ? radiantGold : Colors.white54,
                    ),
                    tooltip: 'تكرار المقطع',
                    onPressed: _toggleLoop,
                  ),

                  // Rewind 10s
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, size: 34),
                    color: Colors.white,
                    tooltip: 'تراجع 10 ثوانٍ',
                    onPressed: () => _seekRelative(-10),
                  ),

                  // Giant Center Play/Pause button
                  GestureDetector(
                    onTap: _isLoading || !_isInit ? null : _togglePlayPause,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: radiantGold.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: deepNavy,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: deepNavy,
                              size: 42,
                            ),
                    ),
                  ),

                  // Forward 10s
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, size: 34),
                    color: Colors.white,
                    tooltip: 'تقديم 10 ثوانٍ',
                    onPressed: () => _seekRelative(10),
                  ),

                  // Speed multiplier
                  TextButton(
                    onPressed: _cycleSpeed,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: radiantGold.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Text(
                      '${_speed}x',
                      style: const TextStyle(
                        color: radiantGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Description or notes if present
              if (widget.resource.description != null &&
                  widget.resource.description!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF16203A)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: radiantGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'عن التسجيل:',
                        style: TextStyle(
                          color: radiantGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.resource.description!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
