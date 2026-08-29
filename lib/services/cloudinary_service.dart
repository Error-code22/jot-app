import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloudinary service that uploads via Supabase Edge Function.
/// No Cloudinary keys in the app — the Edge Function handles it.
class CloudinaryService {
  final String edgeFunctionBaseUrl;

  CloudinaryService({required this.edgeFunctionBaseUrl});

  /// Upload image via Edge Function (which forwards to Cloudinary)
  Future<CloudinaryResult> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$edgeFunctionBaseUrl/image-proxy'),
      );

      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ));
      request.fields['folder'] = folder ?? 'notes';

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Upload failed: $responseBody');
      }

      final json = Map<String, dynamic>.from(
        jsonDecode(responseBody) as Map,
      );

      return CloudinaryResult(
        publicId: json['publicId'] as String,
        url: json['url'] as String,
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      rethrow;
    }
  }

  /// Upload from file
  Future<CloudinaryResult> uploadFile({
    required File file,
    String? folder,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadImage(
      imageBytes: bytes,
      fileName: file.uri.pathSegments.last,
      folder: folder,
    );
  }

  /// Get thumbnail URL from publicId
  String getThumbnailUrl(String publicId, {int size = 200}) {
    final cloudName = 'dazzpcnf9';
    return 'https://res.cloudinary.com/$cloudName/image/upload/w_$size,h_$size,c_fill,q_auto,f_auto/$publicId';
  }

  /// Get the direct image URL (no transformations)
  String getDirectUrl(String publicId) {
    final cloudName = 'dazzpcnf9';
    return 'https://res.cloudinary.com/$cloudName/image/upload/$publicId';
  }
}

class CloudinaryResult {
  final String publicId;
  final String url;
  final int width;
  final int height;

  CloudinaryResult({
    required this.publicId,
    required this.url,
    required this.width,
    required this.height,
  });
}
