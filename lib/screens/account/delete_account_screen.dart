import 'package:flutter/material.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';

import '../../core/services/auth_service.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/theme/app_light_surface.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your VyooO account will be\npermanently deleted',
                      style: TextStyle(
              color: AppLightSurface.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All the information and data will be deleted permanently.',
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppLightSurface.cardFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppLightSurface.border,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/100?img=33',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Matt Rife',
                                  style: TextStyle(
              color: AppLightSurface.primaryText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 12,
                                      color: AppLightSurface.secondaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '@mattrife_x',
                                      style: TextStyle(
                                        color: AppLightSurface.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isDeleting ? null : _confirmDelete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppLightSurface.primaryText,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(64, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _isDeleting ? 'Deleting...' : 'Confirm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _isDeleting ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppLightSurface.primaryText,
                              side: BorderSide(
                                color: AppLightSurface.border,
                              ),
                              minimumSize: const Size(64, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppLightSurface.secondaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: 'Delete Account');
  }

  Future<void> _confirmDelete() async {
    setState(() => _isDeleting = true);
    final res = await AuthService().deleteCurrentAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Could not delete account. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }
}
