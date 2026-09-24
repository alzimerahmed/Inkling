import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/providers/device_preferences_provider.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

/// Settings tile for weather auto-attach (opt-in). When enabled, new stories
/// get the current weather prepended as a text line. Uses Open-Meteo
/// (key-free) and the device's last known location; silently skipped when
/// offline or when location permission was never granted.
class WeatherAutoAttachTile extends StatelessWidget {
  const WeatherAutoAttachTile({super.key, required this.weekday});

  final int weekday;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DevicePreferencesProvider>();
    final enabled = provider.enableWeatherAutoAttach;

    return SwitchListTile(
      secondary: SpSettingIconBadge(weekday: weekday, icon: SpIcons.locationPin),
      title: Text(tr('page.settings.weather_auto_attach.title')),
      subtitle: Text(tr('page.settings.weather_auto_attach.subtitle')),
      value: enabled,
      onChanged: (value) => context.read<DevicePreferencesProvider>().setWeatherAutoAttach(value),
    );
  }
}
