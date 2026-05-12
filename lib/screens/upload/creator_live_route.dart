import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/platform/deferred_agora_ios.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../features/subscription/subscription_screen.dart';
import 'creator_live_screen.dart' deferred as creator;

/// Opens creator live broadcast. Deferred so Agora is not loaded at app/tab startup.
Future<void> openCreatorLiveScreen(BuildContext context) async {
  final subCtrl = context.read<SubscriptionController>();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final canGoLive = await subCtrl.reconcilePaidStatus(firebaseUid: uid);
  if (!context.mounted) return;
  if (!canGoLive) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionScreen(),
      ),
    );
    return;
  }

  await registerDeferredAgoraPluginsIfNeeded();
  await creator.loadLibrary();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => creator.CreatorLiveScreen(),
    ),
  );
}
