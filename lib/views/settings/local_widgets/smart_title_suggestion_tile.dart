import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

/// Settings tile for smart title suggestions (opt-in). When enabled, the
/// editor offers a title derived from the entry's first line. Purely
/// on-device heuristics — no AI model, no network, no telemetry (ADR-012).
class SmartTitleSuggestionTile extends StatelessWidget {
  const SmartTitleSuggestionTile({super.key, required this.weekday});

  final int weekday;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DevicePreferencesProvider>();
    final enabled = provider.enableSmartTitleSuggestion;

    return SwitchListTile(
      secondary: SpSettingIconBadge(weekday: weekday, icon: SpIcons.edit),
      title: Text(tr('page.settings.smart_title_suggestion.title')),
      subtitle: Text(tr('page.settings.smart_title_suggestion.subtitle')),
      value: enabled,
      onChanged: (value) => context
          .read<DevicePreferencesProvider>()
          .setSmartTitleSuggestion(value),
    );
  }
}
