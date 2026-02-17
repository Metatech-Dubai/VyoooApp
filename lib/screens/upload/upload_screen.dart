import 'package:flutter/material.dart';

import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Upload/Create tab. Camera permission requested only when user taps record (store compliant).
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _onCreateTapped() {
    // Permission requested only when user taps — not on screen load (store compliant).
    // TODO: Request camera permission here, then open camera/upload flow.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload flow — request camera permission when implemented'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0015),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 80,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              AppPadding.sectionGap,
              Text(
                'Create',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: AppSpacing.xl + AppSpacing.sm),
              ElevatedButton(
                onPressed: _onCreateTapped,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD10057),
                  foregroundColor: Colors.white,
                  padding: AppPadding.screenHorizontal.copyWith(left: 32, right: 32, top: AppSpacing.md, bottom: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillRadius,
                  ),
                ),
                child: const Text('Record / Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
