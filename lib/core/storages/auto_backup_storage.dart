import 'package:storypad/core/storages/base_object_storages/bool_storage.dart';
import 'package:storypad/core/storages/base_object_storages/integer_storage.dart';
import 'package:storypad/core/storages/base_object_storages/string_storage.dart';

/// Persisted scheduled-local-auto-backup configuration.
///
/// Split across simple typed storages (matching this repo's storage style):
/// - [enabled]: master switch, default off.
/// - [intervalHours]: how often a local backup snapshot is taken.
/// - [keepCount]: retention — newest N auto-backup files are kept.
/// - [lastRunAt]: ISO-8601 timestamp of the last completed auto-backup.
class AutoBackupEnabledStorage extends BoolStorage {}

class AutoBackupIntervalStorage extends IntegerStorage {}

class AutoBackupKeepCountStorage extends IntegerStorage {}

class AutoBackupLastRunStorage extends StringStorage {}
