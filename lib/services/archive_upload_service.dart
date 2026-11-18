import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArchiveUploadResult {
  final bool isSuccess;
  final String? directUrl;
  final String? detailsUrl;
  final String? identifier;
  final String? errorMessage;

  ArchiveUploadResult({
    required this.isSuccess,
    this.directUrl,
    this.detailsUrl,
    this.identifier,
    this.errorMessage,
  });
}

class ArchiveUploadService {
  static const String _keyAccessKey = 'archive_s3_access_key';
  static const String _keySecretKey = 'archive_s3_secret_key';

  static String _userPreferenceKey(String key, String userId) =>
      '${key}_$userId';

  // S3 Credentials Management
  static Future<void> saveCredentials({
    required String accessKey,
    required String secretKey,
  }) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in before saving Archive.org credentials.');
    }

    final normalizedAccessKey = accessKey.trim();
    final normalizedSecretKey = secretKey.trim();
    if (normalizedAccessKey.isEmpty || normalizedSecretKey.isEmpty) {
      throw ArgumentError('Both Archive.org S3 keys are required.');
    }

    final userId = client.auth.currentUser!.id;
    await client.from('archive_credentials').upsert({
      'user_id': userId,
      'access_key': normalizedAccessKey,
      'secret_key': normalizedSecretKey,
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    // Keep an account-scoped cache so uploads can continue during brief outages.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userPreferenceKey(_keyAccessKey, userId),
      normalizedAccessKey,
    );
    await prefs.setString(
      _userPreferenceKey(_keySecretKey, userId),
      normalizedSecretKey,
    );
  }

  static Future<Map<String, String>?> getCredentials() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final accessPreferenceKey = _userPreferenceKey(_keyAccessKey, user.id);
    final secretPreferenceKey = _userPreferenceKey(_keySecretKey, user.id);
    try {
      final row = await client
          .from('archive_credentials')
          .select('access_key, secret_key')
          .eq('user_id', user.id)
          .maybeSingle();
      final access = row?['access_key']?.toString();
      final secret = row?['secret_key']?.toString();
      if (access != null &&
          access.isNotEmpty &&
          secret != null &&
          secret.isNotEmpty) {
        await prefs.setString(accessPreferenceKey, access);
        await prefs.setString(secretPreferenceKey, secret);
        return {'accessKey': access, 'secretKey': secret};
      }
    } catch (error) {
      debugPrint('Could not load saved Archive.org credentials: $error');
    }

    var access = prefs.getString(accessPreferenceKey);
    var secret = prefs.getString(secretPreferenceKey);

    if (access != null &&
        access.isNotEmpty &&
        secret != null &&
        secret.isNotEmpty) {
      return {'accessKey': access, 'secretKey': secret};
    }
    return null;
  }

  static Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds != null;
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await Supabase.instance.client
          .from('archive_credentials')
          .delete()
          .eq('user_id', userId);
      await prefs.remove(_userPreferenceKey(_keyAccessKey, userId));
      await prefs.remove(_userPreferenceKey(_keySecretKey, userId));
    }
    await prefs.remove(_keyAccessKey);
    await prefs.remove(_keySecretKey);
  }

  /// Checks if an Archive.org URL is live and returning HTTP 200/206/302
  /// This checks if Archive.org has finished ingestion & derivation
  static Future<bool> checkResourceReadiness(String directUrl) async {
    try {
      final uri = Uri.parse(directUrl);
      // Make a lightweight range request for 1 byte or head
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ..headers['Range'] = 'bytes=0-0';

      final client = http.Client();
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 8));
      client.close();

      final code = streamedResponse.statusCode;
      // 200 OK, 206 Partial Content, or 302 Redirect mean Archive.org has served the file
      if (code == 200 || code == 206 || code == 302) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Readiness check failed: $e');
      return false;
    }
  }

  /// Extracts the archive details view URL, e.g.
  /// `https://archive.org/details/identifier`.
  static String? getDetailsUrlFromDirectUrl(String? directUrl) {
    if (directUrl == null || directUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(directUrl);
      final segments = uri.pathSegments;
      // Path format: /download/{identifier}/{filename}
      if (segments.length >= 2 && segments[0] == 'download') {
        final identifier = segments[1];
        return 'https://archive.org/details/$identifier';
      }
    } catch (_) {}
    return directUrl;
  }

  /// Maps extension to Archive.org media type and MIME type
  static Map<String, String> getMediaTypeInfo(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf':
        return {
          'mediatype': 'texts',
          'mime': 'application/pdf',
          'appType': 'pdf',
        };
      case 'mp3':
        return {'mediatype': 'audio', 'mime': 'audio/mpeg', 'appType': 'audio'};
      case 'm4a':
        return {'mediatype': 'audio', 'mime': 'audio/mp4', 'appType': 'audio'};
      case 'wav':
        return {'mediatype': 'audio', 'mime': 'audio/wav', 'appType': 'audio'};
      case 'aac':
      case 'ogg':
        return {'mediatype': 'audio', 'mime': 'audio/$ext', 'appType': 'audio'};
      case 'mp4':
        return {'mediatype': 'movies', 'mime': 'video/mp4', 'appType': 'video'};
      case 'mov':
        return {
          'mediatype': 'movies',
          'mime': 'video/quicktime',
          'appType': 'video',
        };
      case 'mkv':
        return {
          'mediatype': 'movies',
          'mime': 'video/x-matroska',
          'appType': 'video',
        };
      case 'webm':
        return {
          'mediatype': 'movies',
          'mime': 'video/webm',
          'appType': 'video',
        };
      case 'jpg':
      case 'jpeg':
        return {'mediatype': 'image', 'mime': 'image/jpeg', 'appType': 'image'};
      case 'png':
        return {'mediatype': 'image', 'mime': 'image/png', 'appType': 'image'};
      case 'gif':
        return {'mediatype': 'image', 'mime': 'image/gif', 'appType': 'image'};
      case 'webp':
        return {'mediatype': 'image', 'mime': 'image/webp', 'appType': 'image'};
      default:
        return {
          'mediatype': 'data',
          'mime': 'application/octet-stream',
          'appType': 'pdf',
        };
    }
  }

  /// Clean filename to be URL-safe for Archive.org S3
  static String sanitizeFileName(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    final ext = lastDot != -1 ? fileName.substring(lastDot) : '';
    final nameWithoutExt = lastDot != -1
        ? fileName.substring(0, lastDot)
        : fileName;

    // Replace non-alphanumeric chars with underscore
    final cleanName = nameWithoutExt
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final safeBase = cleanName.isEmpty ? 'item' : cleanName;
    return '$safeBase$ext';
  }

  /// Direct upload to Internet Archive S3 API
  static Future<ArchiveUploadResult> uploadFile({
    required PlatformFile file,
    required String title,
    String? description,
    String? category,
    String? accessKey,
    String? secretKey,
    void Function(double progress, int bytesSent, int totalBytes)? onProgress,
  }) async {
    try {
      // 1. Resolve Credentials
      String aKey = accessKey?.trim() ?? '';
      String sKey = secretKey?.trim() ?? '';

      if (aKey.isEmpty || sKey.isEmpty) {
        final saved = await getCredentials();
        if (saved != null) {
          aKey = saved['accessKey']!;
          sKey = saved['secretKey']!;
        }
      }

      if (aKey.isEmpty || sKey.isEmpty) {
        return ArchiveUploadResult(
          isSuccess: false,
          errorMessage:
              'Archive.org S3 Credentials are not configured. Please add your Access Key and Secret Key.',
        );
      }

      // 2. Resolve File Data
      Uint8List? fileBytes = file.bytes;
      int totalBytes = file.size;

      if (fileBytes == null && file.path != null && !kIsWeb) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          fileBytes = await ioFile.readAsBytes();
          totalBytes = fileBytes.length;
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        return ArchiveUploadResult(
          isSuccess: false,
          errorMessage:
              'Unable to read file content. Please reselect the file.',
        );
      }

      // 3. Prepare Metadata & Identifier
      final ext = file.extension ?? 'bin';
      final mediaInfo = getMediaTypeInfo(ext);
      final cleanFileName = sanitizeFileName(file.name);
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final identifier = 'alatheer_${mediaInfo['appType']}_$timestamp';

      // Archive.org S3 Endpoint
      final uploadUri = Uri.parse(
        'https://s3.us.archive.org/$identifier/$cleanFileName',
      );

      // Safe header encoding for unicode/Arabic title & description
      final encodedTitle = Uri.encodeComponent(title);
      final encodedDesc = description != null && description.isNotEmpty
          ? Uri.encodeComponent(description)
          : '';
      final encodedCategory = category != null && category.isNotEmpty
          ? Uri.encodeComponent(category)
          : 'Islamic';

      // 4. Build PUT Request
      final client = http.Client();
      final request = http.StreamedRequest('PUT', uploadUri)
        ..headers['authorization'] = 'LOW $aKey:$sKey'
        ..headers['x-archive-auto-make-bucket'] = '1'
        ..headers['x-archive-meta-title'] = encodedTitle
        ..headers['x-archive-meta-mediatype'] = mediaInfo['mediatype']!
        ..headers['x-archive-meta-collection'] = 'opensource_media'
        ..headers['x-archive-meta-creator'] = 'Al-Atheer Publisher'
        ..headers['x-archive-meta-subject'] = encodedCategory
        ..headers['Content-Type'] = mediaInfo['mime']!
        ..contentLength = totalBytes;

      if (encodedDesc.isNotEmpty) {
        request.headers['x-archive-meta-description'] = encodedDesc;
      }

      // 5. Stream with Progress Tracking
      final responseFuture = client.send(request);

      const chunkSize = 64 * 1024; // 64 KB chunks
      int bytesSent = 0;

      for (int i = 0; i < totalBytes; i += chunkSize) {
        final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
        final chunk = fileBytes.sublist(i, end);
        request.sink.add(chunk);
        bytesSent += chunk.length;

        if (onProgress != null) {
          final progress = totalBytes > 0 ? bytesSent / totalBytes : 0.0;
          onProgress(progress.clamp(0.0, 1.0), bytesSent, totalBytes);
        }
        // Yield to event loop to allow UI updates
        await Future.delayed(Duration.zero);
      }

      await request.sink.close();

      // 6. Handle Response
      final response = await responseFuture;
      final responseBody = await response.stream.bytesToString();
      client.close();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final directUrl =
            'https://archive.org/download/$identifier/$cleanFileName';
        final detailsUrl = 'https://archive.org/details/$identifier';

        return ArchiveUploadResult(
          isSuccess: true,
          directUrl: directUrl,
          detailsUrl: detailsUrl,
          identifier: identifier,
        );
      } else {
        debugPrint(
          'Archive.org Upload Error: ${response.statusCode} - $responseBody',
        );
        String err = 'Upload failed with HTTP ${response.statusCode}';
        if (responseBody.contains('AccessDenied') ||
            responseBody.contains('InvalidAccessKeyId')) {
          err =
              'Authentication failed. Please verify your Archive.org S3 Access Key & Secret Key.';
        } else if (responseBody.isNotEmpty && responseBody.length < 200) {
          err = responseBody;
        }

        return ArchiveUploadResult(isSuccess: false, errorMessage: err);
      }
    } catch (e) {
      debugPrint('Archive.org Upload Exception: $e');
      return ArchiveUploadResult(
        isSuccess: false,
        errorMessage: 'An unexpected error occurred during upload: $e',
      );
    }
  }
}
