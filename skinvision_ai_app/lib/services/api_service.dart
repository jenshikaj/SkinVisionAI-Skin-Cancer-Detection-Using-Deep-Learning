// Sends skin images to the SkinVision AI backend for analysis.
// Returns a structured map matching the /api/v1/analyze response.

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Endpoint configuration ──────────────────────────────────────────────────
  // Android emulator  → 10.0.2.2
  // iOS simulator     → localhost
  // Physical device   → machine's LAN IP, e.g. 192.168.1.100
  static const String _baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const Duration _timeout = Duration(seconds: 60);

  // ── analyzeImage ────────────────────────────────────────────────────────────
  /// Uploads [imageFile] to the backend /analyze endpoint.
  /// Returns the full response map including 'insights'.
  ///
  /// Throws an [Exception] on network errors or non-2xx responses.
  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/analyze');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          // Let the server detect the content type
        ),
      );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(_timeout);
    } on SocketException {
      throw Exception(
        'Could not connect to the SkinVision backend.\n'
        'Make sure the server is running and reachable.',
      );
    } on HttpException catch (e) {
      throw Exception('Network error: $e');
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data as Map<String, dynamic>;
    } else if (response.statusCode == 400) {
      final detail = _extractDetail(response.body);
      throw Exception('Invalid image: $detail');
    } else if (response.statusCode == 413) {
      throw Exception('Image is too large. Please use an image under 10 MB.');
    } else if (response.statusCode == 422) {
      throw Exception('Could not read the image file. Try a different image.');
    } else if (response.statusCode == 503) {
      throw Exception(
        'The AI model is not available on the server.\n'
        'Please contact support.',
      );
    } else {
      final detail = _extractDetail(response.body);
      throw Exception(
        'Server error (${response.statusCode}): $detail',
      );
    }
  }

  // ── Health check ─────────────────────────────────────────────────────────────
  static Future<bool> isBackendOnline() async {
    try {
      final res = await http
          .get(Uri.parse('${_baseUrl.replaceAll('/api/v1', '')}/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Helper: extract FastAPI error detail ─────────────────────────────────────
  static String _extractDetail(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail']?.toString() ?? body;
    } catch (_) {
      return body.length > 200 ? '${body.substring(0, 200)}...' : body;
    }
  }
}
