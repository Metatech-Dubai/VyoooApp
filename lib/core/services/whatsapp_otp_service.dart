import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sends and verifies signup WhatsApp OTP via Firestore-triggered Cloud Functions
/// (`processWhatsAppOtpSendRequest` / `processWhatsAppOtpVerifyRequest`).
class WhatsAppOtpService {
  WhatsAppOtpService._();
  static final WhatsAppOtpService _instance = WhatsAppOtpService._();
  factory WhatsAppOtpService() => _instance;

  static bool get _keepDebugOtpDocs => kDebugMode;

  Future<void> requestSendOtp({required String phoneNumber}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in.');
    }
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty || !normalizedPhone.startsWith('+')) {
      throw Exception('Enter a valid WhatsApp number with country code.');
    }
    final ref = FirebaseFirestore.instance
        .collection('whatsapp_otp_send_requests')
        .doc();
    try {
      await ref.set({
        'userId': user.uid,
        'phoneNumber': normalizedPhone,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      final msg = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : e.code;
      throw Exception('Could not create WhatsApp OTP request: $msg');
    }
    try {
      await _waitForRequest(
        ref,
        timeout: const Duration(seconds: 45),
        timeoutMessage: 'Could not send WhatsApp code. Try again.',
      );
    } on FirebaseException catch (e) {
      final msg = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : e.code;
      throw Exception('WhatsApp OTP request failed: $msg');
    }
  }

  Future<void> verifyOtp({
    required String code,
    required String phoneNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in.');
    }
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4) {
      throw Exception('Enter the 4-digit code.');
    }
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty || !normalizedPhone.startsWith('+')) {
      throw Exception('Enter a valid WhatsApp number with country code.');
    }
    final ref = FirebaseFirestore.instance
        .collection('whatsapp_otp_verify_requests')
        .doc();
    try {
      await ref.set({
        'userId': user.uid,
        'phoneNumber': normalizedPhone,
        'code': digits,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      final msg = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : e.code;
      throw Exception('Could not create WhatsApp verification request: $msg');
    }
    try {
      await _waitForRequest(
        ref,
        timeout: const Duration(seconds: 45),
        timeoutMessage: 'WhatsApp verification timed out. Try again.',
      );
    } on FirebaseException catch (e) {
      final msg = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : e.code;
      throw Exception('WhatsApp verification failed: $msg');
    }
  }

  static Future<void> _waitForRequest(
    DocumentReference<Map<String, dynamic>> ref, {
    required Duration timeout,
    required String timeoutMessage,
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;

    sub = ref.snapshots().listen(
      (snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final status = data['status'] as String?;
        if (status == 'done') {
          if (!_keepDebugOtpDocs) {
            unawaited(ref.delete());
          }
          if (!completer.isCompleted) completer.complete();
        } else if (status == 'error') {
          if (!_keepDebugOtpDocs) {
            unawaited(ref.delete());
          }
          final err = data['error'] as String? ?? 'Request failed.';
          if (!completer.isCompleted) {
            completer.completeError(Exception(err));
          }
        }
      },
      onError: (Object e) {
        if (!_keepDebugOtpDocs) {
          unawaited(ref.delete());
        }
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (!_keepDebugOtpDocs) {
            unawaited(ref.delete());
          }
          throw Exception(timeoutMessage);
        },
      );
    } finally {
      sub.cancel();
    }
  }
}
