import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/archive_upload_service.dart';
import '../localization/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasArchiveKeys = false;
  String? _credentialsUserId;

  Future<void> _checkArchiveKeys() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (!auth.isAdmin || userId == null) return;
    final hasKeys = await ArchiveUploadService.hasCredentials();
    if (!mounted || context.read<AuthProvider>().user?.id != userId) return;
    setState(() => _hasArchiveKeys = hasKeys);
  }

  Future<void> _showAdminManagement() async {
    final auth = context.read<AuthProvider>();
    final strings = AppStrings.of(context);
    const radiantGold = Color(0xFFF59E0B);
    final emailController = TextEditingController();
    var adminsFuture = auth.fetchAdminAccessList();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.text('admin_accounts')),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: strings.text('email'),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: strings.text('add_admin'),
                      onPressed: busy
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              if (!email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.text('email_required'),
                                    ),
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => busy = true);
                              final error = await auth.setAdminAccess(
                                email,
                                enabled: true,
                              );
                              if (!context.mounted) return;
                              setDialogState(() => busy = false);
                              if (error != null) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                                return;
                              }
                              emailController.clear();
                              setDialogState(
                                () =>
                                    adminsFuture = auth.fetchAdminAccessList(),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(strings.text('admin_added')),
                                ),
                              );
                            },
                      icon: const Icon(Icons.person_add_alt_1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: adminsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          busy) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'Could not load administrators: ${snapshot.error}',
                        );
                      }
                      final administrators = snapshot.data ?? [];
                      if (administrators.isEmpty) {
                        return Text(strings.text('no_admins'));
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: administrators.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = administrators[index];
                          final email = entry['email']?.toString() ?? '';
                          final isPending = entry['is_pending'] == true;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isPending
                                  ? Icons.mark_email_unread_outlined
                                  : Icons.admin_panel_settings_outlined,
                              color: radiantGold,
                            ),
                            title: Text(
                              entry['display_name']?.toString().isNotEmpty ==
                                      true
                                  ? entry['display_name'].toString()
                                  : email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              isPending ? '$email · Pending signup' : email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: strings.text('remove_admin'),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: Colors.redAccent,
                              ),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      setDialogState(() => busy = true);
                                      final error = await auth.setAdminAccess(
                                        email,
                                        enabled: false,
                                      );
                                      if (!context.mounted) return;
                                      setDialogState(() => busy = false);
                                      if (error != null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(error)),
                                        );
                                        return;
                                      }
                                      setDialogState(
                                        () => adminsFuture = auth
                                            .fetchAdminAccessList(),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            strings.text('admin_removed'),
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.text('cancel')),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
  }

  void _showArchiveKeysDialog() {
    if (!context.read<AuthProvider>().isAdmin) return;

    final strings = AppStrings.of(context);
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
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Text(strings.text('s3_title'), style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.text('s3_desc'),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                  child: Row(
                    children: [
                      const Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.text('get_archive_keys'),
                          style: const TextStyle(
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
                decoration: InputDecoration(
                  labelText: strings.text('access_key'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.text('secret_key'),
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
            child: Text(strings.text('cancel')),
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
                      SnackBar(
                        content: Text(strings.text('archive_keys_saved')),
                        backgroundColor: Color(0xFF0F172A),
                      ),
                    );
                  }
                } catch (error) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Could not save credentials: $error')),
                    );
                  }
                }
              }
            },
            child: Text(strings.text('save_keys')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isAr = settings.isArabic;
    final strings = AppStrings.of(context);
    const radiantGold = Color(0xFFF59E0B);
    const deepEmerald = Color(0xFF0F172A);
    if (auth.isAdmin && _credentialsUserId != auth.user?.id) {
      _credentialsUserId = auth.user?.id;
      _checkArchiveKeys();
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.text('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.isAdmin) ...[
          _buildSectionHeader(context, strings.text('archive_timer')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: radiantGold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isAr
                              ? 'مدة الانتظار بعد الرفع (قبل إتاحة التشغيل)'
                              : 'Buffer Timer After Upload',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr
                        ? 'يستغرق أرشيف الإنترنت وقتاً لفهرسة الملف وتوزيعه على خوادمه العالمية. ضبط هذا المؤقت يمنع ظهور خطأ (غير موجود) عند محاولة الفتح فوراً بعد الرفع.'
                        : 'Archive.org takes time to derive and cache media. This timer prevents 404 Not Found errors.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [60, 90, 120, 180].map((sec) {
                      final isSelected =
                          settings.archiveIngestionDelaySeconds == sec;
                      final label = sec == 60
                          ? '60 ثانية (سريع)'
                          : sec == 90
                          ? '90 ثانية'
                          : sec == 120
                          ? '120 ثانية (موصى به)'
                          : '180 ثانية (مضمون)';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: deepEmerald,
                        labelStyle: TextStyle(
                          color: isSelected ? radiantGold : null,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 11,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? radiantGold
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        onSelected: (_) =>
                            settings.setArchiveIngestionDelay(sec),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.visibility_off_outlined,
                      color: radiantGold,
                    ),
                    title: Text(
                      isAr
                          ? 'إخفاء المواد قيد الفهرسة عن الزوار'
                          : 'Hide pending items from public',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isAr
                          ? 'لا تظهر المواد في التطبيق إلا بعد اكتمال جاهزيتها بالكامل'
                          : 'Items appear in the feed only when indexing completes',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: settings.hideProcessingFromPublic,
                    onChanged: (val) =>
                        settings.setHideProcessingFromPublic(val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ],

          // Theme Section
          _buildSectionHeader(context, strings.text('appearance')),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: radiantGold,
                  ),
                  title: Text(strings.text('dark_mode')),
                  subtitle: Text(strings.text('theme_dark')),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (val) => settings.setThemeMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<ThemeMode>(
                    initialValue: settings.themeMode,
                    decoration: InputDecoration(
                      labelText: strings.text('theme'),
                      prefixIcon: const Icon(Icons.brightness_6_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(strings.text('theme_system')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(strings.text('theme_light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(strings.text('theme_dark')),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) settings.setThemeMode(mode);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.format_size, color: radiantGold),
                  title: Text(strings.text('text_size')),
                  subtitle: Text(strings.text('text_size_desc')),
                  trailing: Text('${(settings.textScale * 100).round()}%'),
                ),
                Slider(
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  value: settings.textScale,
                  label: '${(settings.textScale * 100).round()}%',
                  onChanged: settings.setTextScale,
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.motion_photos_off_outlined,
                    color: radiantGold,
                  ),
                  title: Text(strings.text('reduce_motion')),
                  subtitle: Text(strings.text('reduce_motion_desc')),
                  value: settings.reduceMotion,
                  onChanged: settings.setReduceMotion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Language Section
          _buildSectionHeader(context, strings.text('language')),
          Card(
            child: Column(
              children: AppStrings.supportedLanguages.entries
                  .map(
                    (language) => ListTile(
                      leading: const Icon(Icons.translate, color: radiantGold),
                      title: Text(language.value),
                      trailing: settings.locale.languageCode == language.key
                          ? const Icon(Icons.check_circle, color: radiantGold)
                          : null,
                      onTap: () => settings.setLanguage(language.key),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),

          if (auth.isAdmin) ...[
            _buildSectionHeader(context, strings.text('admin_accounts')),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: radiantGold,
                ),
                title: Text(strings.text('admin_accounts')),
                subtitle: Text(strings.text('admin_accounts_desc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAdminManagement,
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(
              context,
              isAr
                  ? 'التخزين السحابي لأرشيف الإنترنت'
                  : 'Archive.org Cloud Storage',
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _hasArchiveKeys ? Icons.cloud_done : Icons.cloud_off,
                      color: radiantGold,
                    ),
                    title: Text(
                      isAr ? 'مفاتيح Archive.org S3' : 'Archive.org S3 Keys',
                    ),
                    subtitle: Text(
                      _hasArchiveKeys
                          ? (isAr
                                ? 'المفاتيح محفوظة وجاهزة للرفع'
                                : 'Saved to your admin account and ready for uploads')
                          : (isAr
                                ? 'المفاتيح غير مهيأة بعد'
                                : 'Not configured yet'),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deepEmerald,
                        foregroundColor: Colors.white,
                        elevation: 1,
                      ),
                      onPressed: _showArchiveKeysDialog,
                      child: Text(
                        _hasArchiveKeys
                            ? (isAr ? 'تعديل' : 'Edit')
                            : (isAr ? 'تهيئة' : 'Setup'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Account & Admin Section
          _buildSectionHeader(context, strings.text('account')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: radiantGold),
                  title: Text(isAr ? 'حالة الحساب' : 'Account Status'),
                  subtitle: Text(
                    auth.isAuthenticated
                        ? (auth.isAdmin
                              ? (isAr
                                    ? 'مشرف دار النشر (Admin)'
                                    : 'System Admin')
                              : (isAr ? 'مستخدم مسجل' : 'Logged In User'))
                        : (isAr ? 'زائر' : 'Guest User'),
                  ),
                  trailing: auth.isAuthenticated && auth.isAdmin
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: radiantGold),
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/admin'),
                          child: Text(isAr ? 'لوحة التحكم' : 'Dashboard'),
                        )
                      : null,
                ),
                if (auth.isAuthenticated) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: Text(isAr ? 'تسجيل الخروج' : 'Sign Out'),
                    onTap: () async {
                      final error = await auth.signOut();
                      if (!context.mounted) return;
                      if (error != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                      Navigator.pop(context);
                    },
                  ),
                ] else ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.login, color: deepEmerald),
                    title: Text(
                      isAr
                          ? 'تسجيل الدخول / إنشاء حساب'
                          : 'Sign in / Create account',
                    ),
                    onTap: () => Navigator.pushNamed(context, '/login'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 25),

          // App Info Banner
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: deepEmerald.withValues(alpha: 0.1),
                    border: Border.all(
                      color: radiantGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    size: 32,
                    color: radiantGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'تطبيق دار الأثير للنشر • الإصدار 2.5'
                      : 'Al-Atheer Publisher v2.5',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? 'المكتبة الإسلامية والوسائط الرقمية • مدعوم بأرشيف الإنترنت و Supabase'
                      : 'Islamic Digital Library & Media • Powered by Archive.org & Supabase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
