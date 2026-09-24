import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/services/stories/writing_goal_service.dart';
import 'package:storypad/widgets/bottom_sheets/sp_picker_sheet.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_setting_icon_badge.dart';

/// Settings tile for the daily word-count goal. 0 = off.
class WritingGoalTile extends StatefulWidget {
  const WritingGoalTile({super.key, required this.weekday});

  final int weekday;

  @override
  State<WritingGoalTile> createState() => _WritingGoalTileState();
}

class _WritingGoalTileState extends State<WritingGoalTile> {
  int? _goal;

  @override
  void initState() {
    super.initState();
    WritingGoalService.getGoal().then((goal) {
      if (mounted) setState(() => _goal = goal);
    });
  }

  Future<void> pickGoal(BuildContext context) async {
    final current = _goal ?? 0;
    await SpPickerSheet(
      selectedValue: current,
      options: [
        for (final option in WritingGoalService.goalOptions)
          (
            value: option,
            label: option == 0
                ? tr('general.off')
                : tr('page.settings.writing_goal.words_per_day', namedArgs: {'WORDS': '$option'}),
          ),
      ],
      onChanged: (goal) async {
        await WritingGoalService.setGoal(goal);
        if (mounted) setState(() => _goal = goal);
      },
    ).show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final int goal = _goal ?? 0;

    return ListTile(
      leading: SpSettingIconBadge(weekday: widget.weekday, icon: SpIcons.text),
      title: Text(tr('page.settings.writing_goal.title')),
      subtitle: goal > 0
          ? Text(tr('page.settings.writing_goal.words_per_day', namedArgs: {'WORDS': '$goal'}))
          : Text(tr('general.off')),
      onTap: () => pickGoal(context),
    );
  }
}
