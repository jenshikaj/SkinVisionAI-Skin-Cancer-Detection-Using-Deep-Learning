import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/cloudinary_config.dart';

class CloudinaryService {
  /// Uploads [imageFile] to Cloudinary and returns the secure URL.
  /// [folder] organizes files in your Cloudinary Media Library.
  static Future<String> uploadImage(
    File imageFile, {
    String folder = 'skinvision/scans',
  }) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    } else {
      throw Exception(
          'Cloudinary upload failed: ${response.statusCode} — ${response.body}');
    }
  }

  /// Returns an optimized thumbnail URL from a Cloudinary image URL.
  /// Useful for displaying smaller images in scan history lists.
  static String getThumbnailUrl(String originalUrl,
      {int width = 200, int height = 200}) {
    // Insert transformation before upload path segment
    return originalUrl.replaceFirst(
      '/upload/',
      '/upload/w_$width,h_$height,c_fill,q_auto,f_auto/',
    );
  }
}
