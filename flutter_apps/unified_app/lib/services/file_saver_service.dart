import 'dart:io' show Platform, File, Directory;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FileSaveResult {
  final bool success;
  final String fileName;
  final String filePath;
  final String? errorMessage;

  const FileSaveResult({
    required this.success,
    required this.fileName,
    this.filePath = '',
    this.errorMessage,
  });

  @override
  String toString() =>
      'FileSaveResult(success: $success, fileName: $fileName, filePath: $filePath, error: $errorMessage)';
}

class FileSaverService {
  static const MethodChannel _channel =
      MethodChannel('com.yadvi.unified_app/file_saver');

  /// For unit testing platform-specific execution
  @visibleForTesting
  static bool? isAndroidOverride;

  /// Saves binary data (such as a PDF invoice) directly into the device's public Downloads directory.
  /// On Android 10+ (API 29+), uses MediaStore.Downloads.
  /// On older Android, writes to Environment.DIRECTORY_DOWNLOADS and triggers MediaScanner.
  /// On non-Android platforms (desktop/tests), falls back to path_provider downloads/documents.
  static Future<FileSaveResult> savePdfToDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      return FileSaveResult(
        success: false,
        fileName: fileName,
        errorMessage: 'Web platform is not supported via this native saver',
      );
    }

    final isAndroid = isAndroidOverride ?? Platform.isAndroid;

    if (isAndroid) {
      try {
        final result = await _channel.invokeMapMethod<String, dynamic>(
          'savePdfToDownloads',
          {
            'bytes': bytes,
            'fileName': fileName,
          },
        );
        final success = result?['success'] == true;
        final path = result?['path']?.toString() ?? '';
        return FileSaveResult(
          success: success,
          fileName: fileName,
          filePath: path,
        );
      } on PlatformException catch (e) {
        return FileSaveResult(
          success: false,
          fileName: fileName,
          errorMessage: e.message ?? e.toString(),
        );
      } catch (e) {
        return FileSaveResult(
          success: false,
          fileName: fileName,
          errorMessage: e.toString(),
        );
      }
    } else {
      // Non-Android platforms (e.g. desktop runner / unit test environment)
      try {
        Directory? dir;
        try {
          dir = await getDownloadsDirectory();
        } catch (_) {}
        try {
          dir ??= await getApplicationDocumentsDirectory();
        } catch (_) {}

        // In unit tests without path_provider plugin binding
        dir ??= Directory.systemTemp;

        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return FileSaveResult(
          success: true,
          fileName: fileName,
          filePath: file.path,
        );
      } catch (e) {
        return FileSaveResult(
          success: false,
          fileName: fileName,
          errorMessage: e.toString(),
        );
      }
    }
  }
}
