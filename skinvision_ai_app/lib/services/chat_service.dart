import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ChatService {
  // ── Config ────────────────────────────────────────────────────────────────
  // Android emulator  → 10.0.2.2
  // iOS simulator     → localhost
  // Physical device   → your machine's LAN IP e.g. 192.168.1.x
  static const String _baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const Duration _timeout = Duration(seconds: 30);

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String get _uid => _auth.currentUser!.uid;

  /// Reference to this user's chat messages sub-collection.
  static CollectionReference<Map<String, dynamic>> get _chatRef =>
      _db.collection('users').doc(_uid).collection('chat_messages');

  // ── RAG API call ──────────────────────────────────────────────────────────
  /// Sends [question] to the Python RAG backend and returns the answer string.
  static Future<String> sendMessage(String question) async {
    if (question.trim().isEmpty) return 'Please enter a question.';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: jsonEncode({'question': question.trim()}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['answer'] as String? ??
            'No answer received. Please try again.';
      } else if (response.statusCode == 400) {
        return 'Invalid request. Please rephrase your question.';
      } else if (response.statusCode == 500) {
        return 'The server encountered an error. Please try again shortly.';
      } else {
        return 'Unexpected error (${response.statusCode}). Please try again.';
      }
    } on SocketException {
      return '⚠️ Could not connect to the assistant. '
          'Make sure the backend server is running.';
    } on HttpException {
      return '⚠️ Network error. Please check your connection and try again.';
    } on FormatException {
      return '⚠️ Received an unexpected response from the server.';
    } catch (_) {
      return '⚠️ Something went wrong. Please try again.';
    }
  }

  // ── Firestore: save a single message ─────────────────────────────────────
  /// Saves one message (user OR bot) to Firestore.
  static Future<void> saveMessage({
    required String text,
    required bool isUser,
    required DateTime time,
  }) async {
    await _chatRef.add({
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(time),
    });
  }

  // ── Firestore: real-time stream ───────────────────────────────────────────
  /// Live stream of all chat messages, oldest first.
  /// The UI subscribes to this — new messages appear automatically.
  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    return _chatRef.orderBy('timestamp', descending: false).snapshots();
  }

  // ── Firestore: clear chat history ─────────────────────────────────────────
  /// Batch-deletes all chat messages for the current user.
  static Future<void> clearHistory() async {
    final snap = await _chatRef.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Health check ──────────────────────────────────────────────────────────
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
}
