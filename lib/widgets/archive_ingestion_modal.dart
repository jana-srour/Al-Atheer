import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import '../services/archive_upload_service.dart';

class ArchiveIngestionModal extends StatefulWidget {
  final ResourceModel resource;
  final VoidCallback? onReady;

  const ArchiveIngestionModal({
    super.key,
    required this.resource,
    this.onReady,
  });

  static Future<void> show(
    BuildContext context, {
    required ResourceModel resource,
    VoidCallback? onReady,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ArchiveIngestionModal(
        resource: resource,
        onReady: onReady,
      ),
    );
  }

  @override
  State<ArchiveIngestionModal> createState() => _ArchiveIngestionModalState();
}

class _ArchiveIngestionModalState extends State<ArchiveIngestionModal> {
  bool _isChecking = false;
  String? _checkFeedback;

  Future<void> _testReadiness() async {
    setState(() {
      _isChecking = true;
      _checkFeedback = null;
    });

    final resProv = Provider.of<ResourceProvider>(context, listen: false);
    final isReady = await resProv.probeResourceReadiness(widget.resource);

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      if (isReady) {
        _checkFeedback = '🎉 أصبح الملف متاحاً وجاهزاً للفتح الآن!';
      } else {
        _checkFeedback = '⏳ لا يزال أرشيف الإنترنت يعالج الملف، يرجى الانتظار قليلاً.';
      }
    });

    if (isReady) {
      widget.onReady?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final delaySeconds = settings.archiveIngestionDelaySeconds;

    final remainingSec = widget.resource.remainingProcessingSeconds(delaySeconds: delaySeconds);
    final progress = widget.resource.processingProgress(delaySeconds: delaySeconds);
    final formattedTime = widget.resource.formattedRemainingTime(delaySeconds: delaySeconds);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: radiantGold.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: radiantGold.withValues(alpha: 0.15),
                  border: Border.all(color: radiantGold.withValues(alpha: 0.5)),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: radiantGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'جاري التجهيز في أرشيف الإنترنت',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Archive.org Ingestion & Distribution',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular countdown timer & progress
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEEF2FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: radiantGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                // Animated Circular Progress
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: radiantGold.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(radiantGold),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Text(
                            'متبقي',
                            style: TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.resource.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remainingSec > 0
                            ? 'يستغرق أرشيف الإنترنت حوالي دقيقتين لفهرسة الملف وتوزيعه لتجنب ظهور خطأ (غير موجود).'
                            : 'اكتملت مدة الفهرسة، أصبح الملف جاهزاً للبث والقراءة.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3-Stage Pipeline Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStageItem(
                  icon: Icons.cloud_done,
                  label: 'الرفع لـ S3',
                  isDone: true,
                  isActive: false,
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                _buildStageItem(
                  icon: Icons.sync,
                  label: 'الفهرسة والتوليد',
                  isDone: remainingSec == 0,
                  isActive: remainingSec > 0,
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                _buildStageItem(
                  icon: Icons.check_circle_outline,
                  label: 'البث للجميع',
                  isDone: remainingSec == 0,
                  isActive: false,
                ),
              ],
            ),
          ),

          if (_checkFeedback != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _checkFeedback!.contains('🎉')
                    ? radiantGold.withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _checkFeedback!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _checkFeedback!.contains('🎉')
                      ? radiantGold
                      : Colors.amber.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: radiantGold, width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: radiantGold,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh, color: radiantGold, size: 18),
                  label: Text(
                    _isChecking ? 'جاري الفحص...' : 'فحص الجاهزية الآن',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isChecking ? null : _testReadiness,
                ),
              ),
              const SizedBox(width: 10),
              if (widget.resource.archiveUrl != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: radiantGold.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16, color: radiantGold),
                  label: const Text(
                    'صفحة الأرشيف',
                    style: TextStyle(fontSize: 12, color: radiantGold),
                  ),
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
        ],
      ),
    );
  }

  Widget _buildStageItem({
    required IconData icon,
    required String label,
    required bool isDone,
    required bool isActive,
  }) {
    const radiantGold = Color(0xFFF59E0B);
    Color color = Colors.grey;
    if (isDone) color = radiantGold;
    if (isActive) color = radiantGold;

    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: (isDone || isActive) ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
