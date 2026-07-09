import 'package:flutter/material.dart';

import '../../../core/models/user_app_preferences.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';
import 'audience_picker_sheet.dart';
import 'user_preferences_page_mixin.dart';

class TagsMentionsScreen extends StatefulWidget {
  const TagsMentionsScreen({super.key});

  @override
  State<TagsMentionsScreen> createState() => _TagsMentionsScreenState();
}

class _TagsMentionsScreenState extends State<TagsMentionsScreen>
    with UserPreferencesPageMixin {
  Future<void> _pickTags() async {
    final picked = await showAudiencePickerSheet(
      context,
      title: 'Who Can Tag You',
      currentValue: prefs.allowTagsFrom,
    );
    if (picked == null) return;
    await patchUserPreferences((p) => p.copyWith(allowTagsFrom: picked));
  }

  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return SettingsPageShell(title: 'Tags & Mentions', children: [buildPrefsLoading()]);
    }

    return SettingsPageShell(
      title: 'Tags & Mentions',
      subtitle: 'Control when others tag or mention you in posts and comments.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsNavTile(
              title: 'Allow Tags From',
              trailing: AudienceOption.labels[prefs.allowTagsFrom],
              onTap: prefsSaving ? () {} : _pickTags,
            ),
            SettingsSwitchTile(
              title: 'Review Tags Before They Appear',
              subtitle: 'Manually approve tags on your profile (coming to feed)',
              value: false,
              enabled: false,
              onChanged: null,
            ),
          ],
        ),
      ],
    );
  }
}
