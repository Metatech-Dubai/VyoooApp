import 'package:flutter/material.dart';

import '../../../core/widgets/settings/settings_page_shell.dart';
import 'user_preferences_page_mixin.dart';

class StoryReelsPrivacyScreen extends StatefulWidget {
  const StoryReelsPrivacyScreen({super.key});

  @override
  State<StoryReelsPrivacyScreen> createState() => _StoryReelsPrivacyScreenState();
}

class _StoryReelsPrivacyScreenState extends State<StoryReelsPrivacyScreen>
    with UserPreferencesPageMixin {
  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return SettingsPageShell(title: 'Story & Reels', children: [buildPrefsLoading()]);
    }

    return SettingsPageShell(
      title: 'Story & Reels',
      subtitle: 'Sharing and remix controls for stories and reels.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsSwitchTile(
              title: 'Allow Story Resharing',
              subtitle: 'Let others share your story to their story',
              value: prefs.allowStoryReshare,
              enabled: !prefsSaving,
              onChanged: (v) =>
                  patchUserPreferences((p) => p.copyWith(allowStoryReshare: v)),
            ),
            SettingsSwitchTile(
              title: 'Allow Reels Remix',
              subtitle: 'Let others use your audio in their reels',
              value: prefs.allowReelsRemix,
              enabled: !prefsSaving,
              onChanged: (v) =>
                  patchUserPreferences((p) => p.copyWith(allowReelsRemix: v)),
            ),
            SettingsSwitchTile(
              title: 'Hide Story From Close Friends List',
              subtitle: 'Use close friends for exclusive story audience',
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
