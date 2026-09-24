import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/services/backups/auto_backup_service.dart';
import 'package:storypad/core/storages/auto_backup_storage.dart';
import 'package:storypad/widgets/bottom_sheets/sp_picker_sheet.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

/// Settings tile for scheduled local auto-backup. Off by default.
class AutoBackupTile extends StatefulWidget {
  const AutoBackupTile({super.key, required this.weekday});

  final int weekday;

  @override
  State<AutoBackupTile> createState() => _AutoBackupTileState();
}

class _AutoBackupTileState extends State<AutoBackupTile> {
  bool? _enabled;
  int? _intervalHours;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AutoBackupEnabledStorage().read() ?? false;
    final interval = await AutoBackupIntervalStorage().read() ?? AutoBackupService.intervalOptionsInHours.first;
    if (mounted)
      setState(() {
        _enabled = enabled;
        _intervalHours = interval;
      });
  }

  String _label(int hours) {
    if (hours >= 24 && hours % 24 == 0) {
      return tr('page.settings.auto_backup.interval_days', namedArgs: {'DAYS': '${hours ~/ 24}'});
    }
    return tr('page.settings.auto_backup.interval_hours', namedArgs: {'HOURS': '$hours'});
  }

  Future<void> pickInterval(BuildContext context) async {
    final current = _intervalHours ?? AutoBackupService.intervalOptionsInHours.first;
    await SpPickerSheet(
      selectedValue: current,
      options: [for (final hours in AutoBackupService.intervalOptionsInHours) (value: hours, label: _label(hours))],
      onChanged: (hours) async {
        await AutoBackupIntervalStorage().write(hours);
        await AutoBackupEnabledStorage().write(true);
        if (mounted)
          setState(() {
            _intervalHours = hours;
            _enabled = true;
          });
      },
    ).show(context: context);
  }

  Future<void> toggle(bool value) async {
    await AutoBackupEnabledStorage().write(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled ?? false;

    return ListTile(
      leading: SpSettingIconBadge(weekday: widget.weekday, icon: SpIcons.cloudUpload),
      title: Text(tr('page.settings.auto_backup.title')),
      subtitle: enabled
          ? Text(_label(_intervalHours ?? AutoBackupService.intervalOptionsInHours.first))
          : Text(tr('general.off')),
      onTap: () => pickInterval(context),
      trailing: Switch(value: enabled, onChanged: toggle),
    );
  }
}
