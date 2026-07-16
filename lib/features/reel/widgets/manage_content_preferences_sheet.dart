import 'package:flutter/material.dart';

import '../../../../core/theme/app_light_surface.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// "Manage Content Preferences" bottom sheet with four toggles.
void showManageContentPreferencesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ManageContentPreferencesSheet(),
  );
}

class _ManageContentPreferencesSheet extends StatefulWidget {
  const _ManageContentPreferencesSheet();

  @override
  State<_ManageContentPreferencesSheet> createState() =>
      _ManageContentPreferencesSheetState();
}

class _ManageContentPreferencesSheetState
    extends State<_ManageContentPreferencesSheet> {
  bool _limitSensitiveContent = true;
  bool _personaliseContent = true;
  bool _hideSensitiveWords = false;
  bool _showLessPolitical = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppBottomSheet.decoration(topRadius: 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBottomSheet.dragHandle(),
                Text(
                  'Manage Content Preferences',
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _PreferenceSwitch(
                  label: 'Limit sensitive content',
                  value: _limitSensitiveContent,
                  onChanged: (v) => setState(() => _limitSensitiveContent = v),
                ),
                _PreferenceSwitch(
                  label: 'Personalise content based on my activity',
                  value: _personaliseContent,
                  onChanged: (v) => setState(() => _personaliseContent = v),
                ),
                _PreferenceSwitch(
                  label: 'Hide content with sensitive words',
                  value: _hideSensitiveWords,
                  onChanged: (v) => setState(() => _hideSensitiveWords = v),
                ),
                _PreferenceSwitch(
                  label: 'Show less political content',
                  value: _showLessPolitical,
                  onChanged: (v) => setState(() => _showLessPolitical = v),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppLightSurface.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }
}
