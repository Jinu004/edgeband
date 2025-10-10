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
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Use a sub-directory within the app's external files directory for downloads
        final downloadsDir = Directory('${externalDir.path}/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      }
      // Fallback to application documents directory if external storage is not available
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
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              
              // Version Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Version',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.updateInfo.latestVersion,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.updateInfo.fileSizeFormatted,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.blue.shade200),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, 
                          size: 16, 
                          color: Colors.grey[600]
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current: ${widget.updateInfo.currentVersion}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Release Notes
              if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'What\'s New',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        widget.updateInfo.releaseNotes,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              
              // Download Progress
              if (_isDownloading) ...[
                const SizedBox(height: 24),
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: MediaQuery.of(context).size.width * 
                                 _downloadProgress * 0.8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              
              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, 
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Action Buttons
              const SizedBox(height: 24),
              Row(
                children: [
                  if (!widget.forceUpdate && !_isDownloading)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (!widget.forceUpdate && !_isDownloading)
                    const SizedBox(width: 12),
                  if (!_isDownloading)
                    Expanded(
                      flex: widget.forceUpdate ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _downloadUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shadowColor: Colors.blue.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.download, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Update Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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