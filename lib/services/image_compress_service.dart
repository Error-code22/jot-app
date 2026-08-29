import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for compressing images before upload.
class ImageCompressService {
  static const int _defaultMaxWidth = 2048;
  static const int _defaultMaxHeight = 2048;
  static const int _defaultQuality = 80;

  /// Compress an image file
  Future<CompressResult> compressImage({
    required File imageFile,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final targetWidth = maxWidth ?? _defaultMaxWidth;
      final targetHeight = maxHeight ?? _defaultMaxHeight;
      final targetQuality = quality ?? _defaultQuality;

      final result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: targetQuality,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw Exception('Compression failed');
      }

      // Save compressed file
      final tempDir = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final compressedFile = File('${tempDir.path}/$fileName');
      await compressedFile.writeAsBytes(result);

      final originalSize = await imageFile.length();
      final compressedSize = result.length;

      return CompressResult(
        file: compressedFile,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: (1 - compressedSize / originalSize) * 100,
      );
    } catch (e) {
      debugPrint('Image compression error: $e');
      rethrow;
    }
  }

  /// Compress from bytes
  Future<CompressResult> compressImageBytes({
    required Uint8List imageBytes,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final targetWidth = maxWidth ?? _defaultMaxWidth;
      final targetHeight = maxHeight ?? _defaultMaxHeight;
      final targetQuality = quality ?? _defaultQuality;

      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: targetQuality,
        format: CompressFormat.jpeg,
      );

      // Save compressed file
      final tempDir = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final compressedFile = File('${tempDir.path}/$fileName');
      await compressedFile.writeAsBytes(result);

      return CompressResult(
        file: compressedFile,
        originalSize: imageBytes.length,
        compressedSize: result.length,
        compressionRatio: (1 - result.length / imageBytes.length) * 100,
      );
    } catch (e) {
      debugPrint('Image compression error: $e');
      rethrow;
    }
  }

  /// Batch compress multiple images
  Future<List<CompressResult>> batchCompress({
    required List<File> imageFiles,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    final results = <CompressResult>[];
    
    for (final file in imageFiles) {
      final result = await compressImage(
        imageFile: file,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );
      results.add(result);
    }
    
    return results;
  }

  /// Get optimal compression settings based on file size
  CompressionSettings getOptimalSettings(int fileSizeBytes) {
    if (fileSizeBytes < 500 * 1024) {
      // Under 500KB - minimal compression
      return const CompressionSettings(maxWidth: 1920, maxHeight: 1920, quality: 90);
    } else if (fileSizeBytes < 2 * 1024 * 1024) {
      // Under 2MB - moderate compression
      return const CompressionSettings(maxWidth: 1600, maxHeight: 1600, quality: 80);
    } else if (fileSizeBytes < 5 * 1024 * 1024) {
      // Under 5MB - aggressive compression
      return const CompressionSettings(maxWidth: 1200, maxHeight: 1200, quality: 70);
    } else {
      // Over 5MB - maximum compression
      return const CompressionSettings(maxWidth: 1024, maxHeight: 1024, quality: 60);
    }
  }
}

/// Result of image compression
class CompressResult {
  final File file;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;

  CompressResult({
    required this.file,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
  });

  String get originalSizeFormatted => _formatSize(originalSize);
  String get compressedSizeFormatted => _formatSize(compressedSize);
  String get compressionRatioFormatted => '${compressionRatio.toStringAsFixed(1)}%';

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Compression settings
class CompressionSettings {
  final int maxWidth;
  final int maxHeight;
  final int quality;

  const CompressionSettings({
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });
}
