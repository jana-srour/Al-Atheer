import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_brand_logo.dart';

class AdminAppBrandingScreen extends StatefulWidget {
  const AdminAppBrandingScreen({super.key});

  @override
  State<AdminAppBrandingScreen> createState() => _AdminAppBrandingScreenState();
}

class _AdminAppBrandingScreenState extends State<AdminAppBrandingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _arabicNameController;
  late final TextEditingController _englishNameController;
  Uint8List? _selectedLogoBytes;
  String? _selectedLogoName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _arabicNameController = TextEditingController(text: settings.appNameAr);
    _englishNameController = TextEditingController(text: settings.appNameEn);
  }

  @override
  void dispose() {
    _arabicNameController.dispose();
    _englishNameController.dispose();
    super.dispose();
  }

  Future<void> _selectLogo() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
    } catch (error) {
      if (mounted) _showMessage('Could not select the image: $error');
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('Could not read the selected image.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('Choose an image smaller than 5 MB.');
      return;
    }
    setState(() {
      _selectedLogoBytes = bytes;
      _selectedLogoName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final settings = context.read<SettingsProvider>();
      var logoUrl = settings.appLogoUrl;
      final selectedBytes = _selectedLogoBytes;
      final selectedName = _selectedLogoName;
      if (selectedBytes != null && selectedName != null) {
        logoUrl = await settings.uploadAppLogo(selectedBytes, selectedName);
      }
      await settings.saveAppBranding(
        appNameAr: _arabicNameController.text,
        appNameEn: _englishNameController.text,
        logoUrl: logoUrl,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('App branding updated.')),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not save app branding: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('App branding')),
        body: const Center(child: Text('Administrator access is required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('App and website branding')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: _selectedLogoBytes == null
                      ? AppBrandLogo(
                          imageUrl: settings.appLogoUrl,
                          size: 96,
                          fallbackColor: Theme.of(context).colorScheme.primary,
                        )
                      : ClipOval(
                          child: Image.memory(
                            _selectedLogoBytes!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _selectLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_selectedLogoName ?? 'Choose a new logo'),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _arabicNameController,
                  maxLength: 60,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'App name (Arabic)',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _englishNameController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'App name (English)',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                Text(
                  'The name and logo update in the app and website. Installed '
                  'mobile launcher names and icons remain controlled by the '
                  'Android/iOS app release.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (settings.appBrandingError case final error?) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save branding'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an app name.';
    }
    if (value.trim().length > 60) {
      return 'App names must be 60 characters or fewer.';
    }
    return null;
  }
}
