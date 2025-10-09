import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppUpdater {
  final String githubOwner = "Sonusubi";
  final String githubRepo = "edgeband-apk";
  
  String get githubApiUrl => 
      "https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest";

  // Check for updates with optional UI callback
  Future<UpdateInfo?> checkForUpdate({
    Function(String)? onError,
    bool showLoading = true,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final releaseData = jsonDecode(response.body);
        final latestVersion = releaseData['tag_name']?.replaceAll('v', '') ?? '';
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(latestVersion, currentVersion)) {
          final assets = releaseData['assets'] as List;
          final apkAsset = assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );

          if (apkAsset != null) {
            return UpdateInfo(
              latestVersion: latestVersion,
              currentVersion: currentVersion,
              downloadUrl: apkAsset['browser_download_url'],
              releaseNotes: releaseData['body'] ?? '',
              fileName: apkAsset['name'],
              fileSize: apkAsset['size'],
            );
          }
        }
      } else if (response.statusCode == 404) {
        onError?.call('No releases found');
      } else {
        onError?.call('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      onError?.call('Error checking for updates: $e');
    }
    return null;
  }

  // Compare version strings (e.g., "1.2.3" vs "1.2.4")
  bool _isNewerVersion(String latestVersion, String currentVersion) {
    final latest = latestVersion.split('.').map(int.tryParse).toList();
    final current = currentVersion.split('.').map(int.tryParse).toList();

    for (int i = 0; i < latest.length && i < current.length; i++) {
      if (latest[i] == null || current[i] == null) return false;
      if (latest[i]! > current[i]!) return true;
      if (latest[i]! < current[i]!) return false;
    }
    return latest.length > current.length;
  }

  // Download and install update with progress tracking
  Future<bool> downloadAndInstall(
    UpdateInfo updateInfo, {
    Function(double)? onProgress,
    Function(String)? onError,
    Function()? onComplete,
  }) async {
    try {
      // Request storage permission for Android 10 and below
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        if (androidInfo < 30) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            onError?.call('Storage permission denied');
            return false;
          }
        }
        
        // Request install packages permission
        final installStatus = await Permission.requestInstallPackages.request();
        if (!installStatus.isGranted) {
          onError?.call('Install permission denied');
          return false;
        }
      }

      // Get download directory
      final directory = await _getDownloadDirectory();
      final filePath = '${directory.path}/${updateInfo.fileName}';
      final file = File(filePath);

      // Delete existing file if present
      if (await file.exists()) {
        await file.delete();
      }

      // Download with progress tracking
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? updateInfo.fileSize;
        int bytesReceived = 0;

        final sink = file.openWrite();
        await response.stream.map((chunk) {
          bytesReceived += chunk.length;
          final progress = bytesReceived / contentLength;
          onProgress?.call(progress);
          return chunk;
        }).pipe(sink);

        await sink.close();

        onComplete?.call();

        // Open APK for installation
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          onError?.call('Failed to open installer: ${result.message}');
          return false;
        }

        return true;
      } else {
        onError?.call('Download failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      onError?.call('Error downloading update: $e');
      return false;
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Try to use Downloads directory first
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        return downloadsDir;
      }
      // Fallback to external storage
      final dir = await getExternalStorageDirectory();
      return dir!;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      final info = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(info.stdout.toString().trim()) ?? 0;
    }
    return 0;
  }

  // Show update dialog
  static void showUpdateDialog(
    BuildContext context,
    UpdateInfo updateInfo, {
    bool forceUpdate = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => UpdateDialog(
        updateInfo: updateInfo,
        forceUpdate: forceUpdate,
      ),
    );
  }
}

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String fileName;
  final int fileSize;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fileName,
    required this.fileSize,
  });

  String get fileSizeFormatted {
    final sizeInMB = fileSize / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(2)} MB';
  }
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final bool forceUpdate;

  const UpdateDialog({
    Key? key,
    required this.updateInfo,
    this.forceUpdate = false,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  final AppUpdater _updater = AppUpdater();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.forceUpdate && !_isDownloading,
      child: AlertDialog(
        title: const Text('Update Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version ${widget.updateInfo.latestVersion}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current version: ${widget.updateInfo.currentVersion}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Size: ${widget.updateInfo.fileSizeFormatted}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                const Text(
                  'What\'s New:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.updateInfo.releaseNotes,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.forceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          if (!_isDownloading)
            ElevatedButton(
              onPressed: _downloadUpdate,
              child: const Text('Update Now'),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    final success = await _updater.downloadAndInstall(
      widget.updateInfo,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
          _isDownloading = false;
        });
      },
      onComplete: () {
        // Download complete, installation will start automatically
      },
    );

    if (!success && mounted) {
      setState(() {
        _isDownloading = false;
      });
    }
  }
}

// Usage Example
class UpdateChecker {
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool forceUpdate = false,
    bool silent = false,
  }) async {
    final updater = AppUpdater();
    
    final updateInfo = await updater.checkForUpdate(
      onError: (error) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
    );

    if (updateInfo != null) {
      AppUpdater.showUpdateDialog(
        context,
        updateInfo,
        forceUpdate: forceUpdate,
      );
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version')),
      );
    }
  }
}