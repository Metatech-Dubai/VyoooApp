import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../subscription/subscription_screen.dart';
import 'vr_player_screen.dart';

/// VR feature screen. Subscription-gated: Standard → locked, Subscriber/Creator → grid.
class VrScreen extends StatelessWidget {
  const VrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.feed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFeedHeader(selectedIndex: 1),
            Expanded(
              child: Consumer<SubscriptionController>(
                builder: (context, subscriptionController, _) {
                  if (!subscriptionController.hasVRAccess) {
                    return const VrLockedView();
                  }
                  return const VrGridView();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// VR paywall content. Reused in home screen when VR tab is selected.
class VrLockedView extends StatelessWidget {
  const VrLockedView();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final cardHeight = screenHeight * 0.45;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underwater-style placeholder background (gradient only; no dart:ui)
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A1628),
                Color(0xFF0D2D4A),
                Color(0xFF1A0030),
              ],
            ),
          ),
        ),
        // Bottom payment card
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: cardHeight,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: AppGradients.vrPaymentCardGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Stream Your Way – Pay by the Minute!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Stream 360° content by the minute. No commitments, just click and enjoy!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.vrGetStartedButtonGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pay-per-minute coming soon'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Get started'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text(
                          'or',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Become a Member to Watch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Stream Exclusive Live streams, Immersive VR Content, Monetize Content and many more',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SubscriptionScreen(
                              showRestoreButton: true,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('See Plans'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// VR grid of thumbnails. Reused in home screen when VR tab is selected.
class VrGridView extends StatelessWidget {
  const VrGridView();

  static const _thumbnailUrls = [
    'https://picsum.photos/400/400?random=1',
    'https://picsum.photos/400/400?random=2',
    'https://picsum.photos/400/400?random=3',
    'https://picsum.photos/400/400?random=4',
    'https://picsum.photos/400/400?random=5',
    'https://picsum.photos/400/400?random=6',
    'https://picsum.photos/400/400?random=7',
    'https://picsum.photos/400/400?random=8',
    'https://picsum.photos/400/400?random=9',
  ];

  /// Test video URLs for development. Each grid item uses one by index.
  static final _testVideoUrls = [
    ...VrPlayerScreen.testVideoUrls,
    ...VrPlayerScreen.testVideoUrls,
    ...VrPlayerScreen.testVideoUrls,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _thumbnailUrls.length,
        itemBuilder: (context, index) {
          final videoUrl = _testVideoUrls[index % _testVideoUrls.length];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VrPlayerScreen(
                    title: 'VR ${index + 1}',
                    videoUrl: videoUrl,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _thumbnailUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white12,
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white38,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
