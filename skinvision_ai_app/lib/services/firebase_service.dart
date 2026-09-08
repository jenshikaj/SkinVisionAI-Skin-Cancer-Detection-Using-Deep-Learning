import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'cloudinary_service.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get uid => _auth.currentUser!.uid;

  // ── Save user profile to Firestore ──
  static Future<void> saveProfile(Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Get user profile from Firestore ──
  static Future<Map<String, dynamic>?> getProfile() async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ── Save scan: upload image to Cloudinary, save details to Firestore ──
  static Future<String> saveScan({
    required File imageFile,
    required Map<String, dynamic> scanData,
  }) async {
    // 1. Upload image to Cloudinary (free)
    final imageUrl = await CloudinaryService.uploadImage(
      imageFile,
      folder: 'skinvision/scans/$uid',
    );

    // 2. Save scan metadata + Cloudinary URL to Firestore
    final docRef =
        await _db.collection('users').doc(uid).collection('scans').add({
      ...scanData,
      'imageUrl': imageUrl, // Cloudinary secure URL
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ── Stream scan history from Firestore ──
  static Stream<QuerySnapshot> scanHistory() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('scans')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  // ── Save disease insights for a scan (nested Firestore doc) ──
  static Future<void> saveInsights({
    required String scanId,
    required Map<String, dynamic> insights,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('scans')
        .doc(scanId)
        .update({
      'insights': insights,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Get a single scan with its insights ──
  static Future<Map<String, dynamic>?> getScan(String scanId) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('scans')
        .doc(scanId)
        .get();
    return doc.exists ? doc.data() : null;
  }
}
