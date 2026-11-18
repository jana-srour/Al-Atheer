import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../localization/app_strings.dart';

class IslamicHeaderWidget extends StatelessWidget {
  final VoidCallback onOpenAdmin;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPlaylists;
  final VoidCallback onOpenBiography;
  final VoidCallback onToggleFavorites;
  final bool isFavoritesSelected;

  const IslamicHeaderWidget({
    super.key,
    required this.onOpenAdmin,
    required this.onOpenSettings,
    required this.onOpenPlaylists,
    required this.onOpenBiography,
    required this.onToggleFavorites,
    required this.isFavoritesSelected,
  });

  /// Calculates approximate Hijri date for display
  static String getTodayHijriDate() {
    final now = DateTime.now();
    // Standard Islamic month names
    const hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    // High-accuracy astronomical conversion estimation
    final jd = now.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    final l = (jd - 1948440 + 10632).toInt();
    final n = ((l - 1) / 10631).toInt();
    final l1 = l - 10631 * n + 354;
    final j =
        ((10985 - l1) / 5316).toInt() * ((50 * l1) / 17719).toInt() +
        (l1 / 5670).toInt() * ((43 * l1) / 15238).toInt();
    final l2 =
        l1 -
        ((30 - j) / 15).toInt() * ((17719 * j) / 50).toInt() -
        (j / 16).toInt() * ((15238 * j) / 43).toInt() +
        29;
    final m = ((24 * l2) / 709).toInt();
    final day = l2 - ((709 * m) / 24).toInt();
    final year = (30 * n + j - 30) + 1;

    final monthName = (m >= 1 && m <= 12) ? hijriMonths[m - 1] : hijriMonths[0];
    return '$day $monthName $year هـ';
  }

  static String toArabicDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  Future<void> _openAccount(BuildContext context, AuthProvider auth) async {
    final strings = AppStrings.of(context);
    if (!auth.isAuthenticated) {
      await Navigator.pushNamed(context, '/login');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountSheet(
        auth: auth,
        strings: strings,
        rootContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    final auth = Provider.of<AuthProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final hijriDate = toArabicDigits(getTodayHijriDate());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF060D1A), Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Keep the date and controls together at the left edge.
            Align(
              alignment: Alignment.centerLeft,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                // Hijri Date Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: radiantGold.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 13,
                        color: radiantGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hijriDate,
                        style: const TextStyle(
                          color: radiantGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Actions (Favorites, Admin, Settings)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Favorites Filter Button
                    InkWell(
                      onTap: onToggleFavorites,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isFavoritesSelected
                              ? radiantGold
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFavoritesSelected
                                ? radiantGold
                                : radiantGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFavoritesSelected
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 15,
                              color: isFavoritesSelected
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                            ),
                            if (settings.favoriteIds.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${settings.favoriteIds.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isFavoritesSelected
                                      ? const Color(0xFF0F172A)
                                      : radiantGold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    IconButton(
                      icon: const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'قوائم التشغيل والدورات',
                      onPressed: onOpenPlaylists,
                    ),

                    IconButton(
                      icon: const Icon(
                        Icons.person_search_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'عن الكاتب',
                      onPressed: onOpenBiography,
                    ),

                    // Admin Studio Shortcut
                    if (auth.isAuthenticated && auth.isAdmin)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: radiantGold.withValues(alpha: 0.6),
                            ),
                            color: radiantGold.withValues(alpha: 0.15),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: radiantGold,
                            size: 16,
                          ),
                        ),
                        tooltip: AppStrings.of(
                          context,
                        ).text('publisher_studio'),
                        onPressed: onOpenAdmin,
                      ),

                    // Settings Button
                    IconButton(
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Settings',
                      onPressed: onOpenSettings,
                    ),
                    ],
                  ),
                ],
              ),
            ),
          ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: InkWell(
                onTap: auth.isLoading
                    ? null
                    : () => _openAccount(context, auth),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: radiantGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        auth.isAuthenticated
                            ? Icons.account_circle
                            : Icons.person_outline,
                        color: radiantGold,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          auth.isLoading
                              ? AppStrings.of(context).text('account_loading')
                              : auth.isAuthenticated
                              ? auth.displayName
                              : AppStrings.of(context).text('guest'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more,
                        color: Colors.white70,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Logo & Title Header
            Row(
              children: [
                // Glowing Gold Ring Logo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: radiantGold.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    size: 24,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأثير للنشر والتوزيع',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Al-Atheer Islamic Library & Digital Media',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSheet extends StatefulWidget {
  final AuthProvider auth;
  final AppStrings strings;
  final BuildContext rootContext;

  const _AccountSheet({
    required this.auth,
    required this.strings,
    required this.rootContext,
  });

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.auth.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF0F172A),
                    foregroundColor: Color(0xFFF59E0B),
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isAdmin
                              ? '${auth.displayName} · ${strings.text('admin')}'
                              : auth.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          auth.user?.email ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (auth.profileError != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.profileError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: strings.text('profile_name'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final error = await auth.updateDisplayName(
                          _nameController.text,
                        );
                        if (!context.mounted) return;
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        if (widget.rootContext.mounted) {
                          ScaffoldMessenger.of(
                            widget.rootContext,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(strings.text('profile_saved')),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(strings.text('save_name')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        Navigator.pop(context);
                        final error = await auth.signOut();
                        if (error != null && widget.rootContext.mounted) {
                          ScaffoldMessenger.of(
                            widget.rootContext,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: Text(strings.text('sign_out')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
