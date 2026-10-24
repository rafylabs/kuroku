import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../network/http_client.dart';

class AppReleaseInfo {
  final String tagName;
  final String version;
  final String name;
  final String body;
  final String apkUrl;
  final String ipaUrl;
  final int apkSize;
  final DateTime publishedAt;

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.apkUrl,
    required this.ipaUrl,
    required this.apkSize,
    required this.publishedAt,
  });
}

class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._internal();
  AppUpdateService._internal();

  static const String currentVersion = '1.3.2';
  static const MethodChannel _channel = MethodChannel('com.rafylabs.kuroku/updater');

  /// Compare two semver strings: returns true if [remote] is strictly greater than [current]
  bool isVersionNewer(String remote, String current) {
    try {
      final rParts = remote.replaceAll('v', '').split('.').map(int.parse).toList();
      final cParts = current.replaceAll('v', '').split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return remote != current;
    }
  }

  Future<AppReleaseInfo?> checkUpdate() async {
    try {
      final res = await KurokuHttpClient.instance.get<Map<String, dynamic>>(
        'https://api.github.com/repos/rafylabs/kuroku/releases/latest',
        headers: {'User-Agent': 'Kuroku-Updater'},
      );

      final data = res.data;
      if (data == null) return null;

      final tagName = data['tag_name'] as String? ?? '';
      final rawVersion = tagName.replaceAll('v', '').trim();

      if (!isVersionNewer(rawVersion, currentVersion)) {
        return null;
      }

      String apkUrl = '';
      String ipaUrl = '';
      int apkSize = 0;

      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final a in assets) {
        if (a is! Map<String, dynamic>) continue;
        final name = a['name'] as String? ?? '';
        final url = a['browser_download_url'] as String? ?? '';
        final size = a['size'] as int? ?? 0;

        if (name.endsWith('.apk')) {
          apkUrl = url;
          apkSize = size;
        } else if (name.endsWith('.ipa')) {
          ipaUrl = url;
        }
      }

      return AppReleaseInfo(
        tagName: tagName,
        version: rawVersion,
        name: data['name'] as String? ?? 'New Kuroku Version',
        body: data['body'] as String? ?? '',
        apkUrl: apkUrl,
        ipaUrl: ipaUrl,
        apkSize: apkSize,
        publishedAt: DateTime.tryParse(data['published_at'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadAndInstallApk(
    AppReleaseInfo release, {
    Function(double progress, int received, int total)? onProgress,
  }) async {
    if (release.apkUrl.isEmpty) {
      throw Exception('APK download URL not found in release');
    }

    final cacheDir = await getTemporaryDirectory();
    final apkFile = File('${cacheDir.path}/Kuroku-v${release.version}.apk');

    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    await KurokuHttpClient.instance.dio.download(
      release.apkUrl,
      apkFile.path,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          onProgress?.call(progress, received, total);
        }
      },
    );

    if (!await apkFile.exists() || await apkFile.length() == 0) {
      throw Exception('Downloaded file is empty or missing');
    }

    // Trigger system installer on Android
    if (Platform.isAndroid) {
      await _channel.invokeMethod('installApk', {'filePath': apkFile.path});
    }
  }

  void showUpdateDialog(BuildContext context, AppReleaseInfo release) {
    double? downloadProgress;
    bool isDownloading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.system_update_rounded, color: Color(0xFF00F0FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update Tersedia (${release.tagName})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versi saat ini: v$currentVersion\nVersi baru: ${release.tagName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (release.body.isNotEmpty) ...[
                    const Text(
                      'Catatan Rilis:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        release.body,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isDownloading) ...[
                    LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF00F0FF),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        downloadProgress != null
                            ? 'Mengunduh update... ${(downloadProgress! * 100).toInt()}%'
                            : 'Mempersiapkan unduhan...',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF00F0FF)),
                      ),
                    ),
                  ],
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (!isDownloading)
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Nanti', style: TextStyle(color: Colors.grey)),
                ),
              if (!isDownloading)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    setDialogState(() {
                      isDownloading = true;
                      errorMessage = null;
                    });

                    try {
                      await downloadAndInstallApk(
                        release,
                        onProgress: (p, rec, tot) {
                          setDialogState(() {
                            downloadProgress = p;
                          });
                        },
                      );
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }
                    } catch (e) {
                      setDialogState(() {
                        isDownloading = false;
                        errorMessage = 'Gagal mengunduh: $e';
                      });
                    }
                  },
                  child: const Text('Update Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }
}
