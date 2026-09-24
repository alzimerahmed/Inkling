import 'package:storypad/core/databases/models/story_content_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/story_page_db_model.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';
import 'package:storypad/core/types/path_type.dart';

/// Maps a parsed [ImportedStoryDraft] onto Inkling's existing
/// [StoryDbModel] fields — no ObjectBox schema change needed.
///
/// - date → year/month/day/hour/minute/second (+ createdAt/updatedAt)
/// - title → content title (Day One/Daylio: first line promoted when it is
///   short and the body has more lines)
/// - body → single Quill delta page (plain text insert)
/// - tags → resolved by the importer (TagDbModel ids as strings)
/// - feeling → legacy `feeling` field
class ImportStoryMapper {
  static StoryDbModel toStory({
    required ImportedStoryDraft draft,
    required int id,
    required List<String> tagIds,
    List<String> bodyLines = const [],
  }) {
    final bodyText = [if (draft.hasBody) draft.body!.trim(), ...bodyLines].join('\n\n');

    final title = _resolveTitle(draft);
    final deltaBody = [
      {'insert': '$bodyText\n'},
    ];

    final content = StoryContentDbModel.create(createdAt: draft.date).copyWith(
      title: title,
      richPages: [StoryPageDbModel(id: draft.date.millisecondsSinceEpoch, title: title, body: deltaBody)],
    );

    return StoryDbModel(
      type: PathType.docs,
      id: id,
      starred: false,
      pinned: false,
      feeling: draft.feeling,
      preferencesOrNull: null,
      year: draft.date.year,
      month: draft.date.month,
      day: draft.date.day,
      hour: draft.date.hour,
      minute: draft.date.minute,
      second: draft.date.second,
      updatedAt: draft.date,
      createdAt: draft.date,
      lastSavedDeviceId: null,
      galleryTemplateId: null,
      templateId: null,
      tags: tagIds,
      assets: [],
      movedToBinAt: null,
      latestContent: content,
      draftContent: null,
      permanentlyDeletedAt: null,
    );
  }

  /// Keep/Evernote carry explicit titles. For body-only sources (Day One,
  /// Daylio), promote the first line to the title when it is short and the
  /// entry has more content — mirrors how users think of those entries.
  static String? _resolveTitle(ImportedStoryDraft draft) {
    if (draft.title != null && draft.title!.trim().isNotEmpty) return draft.title!.trim();
    if (!draft.hasBody) return null;

    final lines = draft.body!.trim().split('\n');
    final first = lines.first.trim();
    if (lines.length > 1 && first.isNotEmpty && first.length <= 80) {
      return first;
    }
    return null;
  }
}
