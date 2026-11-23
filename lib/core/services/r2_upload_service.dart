import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Uploads one original 360 / VR file straight to Cloudflare R2.
///
/// The Cloud Function only returns a one-time PUT URL. The video bytes never
/// pass through the function.
class R2UploadService {
  R2UploadService._();

  static final R2UploadService instance = R2UploadService._();

  static const Duration _urlWait = Duration(seconds: 45);
  static const Duration _putTimeout = Duration(minutes: 45);

  Future<String> put({
    required File file,
    required String kind,
    required String contentType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('Sign in before uploading.');
    }
    if (!await file.exists()) {
      throw StateError('File to upload was not found.');
    }
    final length = await file.length();
    if (length <= 0) {
      throw StateError('File to upload is empty.');
    }

    final db = FirebaseFirestore.instance;
    final reqRef = await db.collection('r2_upload_requests').add({
      'userId': uid,
      'kind': kind,
      'contentType': contentType,
      'contentLength': length,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    String uploadUrl = '';
    String publicUrl = '';
    try {
      final deadline = DateTime.now().add(_urlWait);
      await for (final snap in reqRef.snapshots()) {
        final data = snap.data();
        if (data == null) continue;
        final status = (data['status'] as String?) ?? '';
        if (status == 'done') {
          uploadUrl = (data['uploadUrl'] as String?)?.trim() ?? '';
          publicUrl = (data['publicUrl'] as String?)?.trim() ?? '';
          break;
        }
        if (status == 'error') {
          final message = (data['error'] as String?)?.trim();
          throw Exception(
            message == null || message.isEmpty ? 'Could not prepare upload.' : message,
          );
        }
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('Timed out waiting for upload URL.');
        }
      }
    } finally {
      await reqRef.delete().catchError((_) {});
    }

    final target = Uri.tryParse(uploadUrl);
    final published = Uri.tryParse(publicUrl);
    if (target == null || target.scheme != 'https' || published == null || published.scheme != 'https') {
      throw Exception('Upload URL was not valid.');
    }

    final client = http.Client();
    try {
      final request = http.StreamedRequest('PUT', target)
        ..contentLength = length
        ..headers['Content-Type'] = contentType;
      await request.sink.addStream(file.openRead());
      await request.sink.close();
      final response = await client.send(request).timeout(_putTimeout);
      await response.stream.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Upload failed (${response.statusCode}).');
      }
    } finally {
      client.close();
    }

    return publicUrl;
  }
}
