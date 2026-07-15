import 'package:flutter/material.dart';
import '../../core/strings/app_strings.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import '../../core/widgets/app_gradient_background.dart';

import 'live_stream_monetisation_screen.dart';
import 'manage_subscriptions_screen.dart';
import '../../core/theme/app_light_surface.dart';

class SettingsSubscriptionsScreen extends StatelessWidget {
  const SettingsSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppLightSurface.cardFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppLightSurface.border,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _SubscriptionRow(
                            label: AppStrings.manageSubscriptions,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ManageSubscriptionsScreen(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _SubscriptionRow(
                            label: AppStrings.liveStreamMonetization,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const LiveStreamMonetisationScreen(),
                                ),
                              );
                            },
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: AppStrings.subscriptions);
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppLightSurface.cardFill,
      indent: 0,
      endIndent: 0,
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppLightSurface.secondaryText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
