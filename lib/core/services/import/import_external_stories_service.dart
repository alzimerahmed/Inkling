import 'dart:io';
import 'package:storypad/core/databases/models/asset_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/tag_category_db_model.dart';
import 'package:storypad/core/databases/models/tag_db_model.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';
import 'package:storypad/core/services/import/import_story_mapper.dart';
import 'package:storypad/core/services/tag_id_generator_service.dart';
import 'package:storypad/core/types/asset_type.dart';

/// Result of a confirmed external import.
typedef ImportExternalResult = ({
  int imported,
  int tagsCreated,
  int photosImported,
  int photosSkipped,
});

/// Writes parsed external drafts into Inkling's ObjectBox stores.
///
/// Parsing happens off the main isolate (see the parsers); DB writes happen
/// here on the main isolate because the ObjectBox store is per-isolate.
class ImportExternalStoriesService {
  /// Result of a confirmed import.
  static Future<ImportExternalResult> call({
    required List<ImportedStoryDraft> drafts,
    required Map<String, String> photoFiles,
    bool mapMoodsToFeelingTags = false,
  }) async {
    int imported = 0;
    int photosImported = 0;
    int photosSkipped = 0;

    // Resolve/create tags once, shared across all drafts.
    final tagIdsByTitle = <String, String>{};
    for (final draft in drafts) {
      for (final title in draft.tags) {
        final key = title.trim().toLowerCase();
        if (key.isEmpty || tagIdsByTitle.containsKey(key)) continue;
        final existing = await _findTagByTitle(key);
        tagIdsByTitle[key] =
            existing?.id.toString() ??
            await (mapMoodsToFeelingTags
                ? _createFeelingTag(title.trim())
                : _createTag(title.trim()));
      }
    }

    for (final draft in drafts) {
      final tagIds = draft.tags
          .map((t) => tagIdsByTitle[t.trim().toLowerCase()])
          .whereType<String>()
          .toList();

      final resolvedPhotos = await _resolvePhotos(
        draft.photoFileNames,
        photoFiles,
      );
      photosImported += resolvedPhotos.imported.length;
      photosSkipped +=
          draft.photoFileNames.length - resolvedPhotos.imported.length;

      final story = ImportStoryMapper.toStory(
        draft: draft,
        id: draft.date.millisecondsSinceEpoch,
        tagIds: tagIds,
        bodyLines: resolvedPhotos.embedLines,
      );

      final existing = await StoryDbModel.db.find(story.id);
      if (existing != null) {
        // Deterministic id collision (same millisecond) — shift forward until
        // free so an import never overwrites existing user data.
        int shiftedId = story.id;
        do {
          shiftedId += 1;
        } while (await StoryDbModel.db.find(shiftedId) != null);
        await StoryDbModel.db.set(
          ImportStoryMapper.toStory(
            draft: draft,
            id: shiftedId,
            tagIds: tagIds,
            bodyLines: resolvedPhotos.embedLines,
          ),
          runCallbacks: false,
        );
      } else {
        await StoryDbModel.db.set(story, runCallbacks: false);
      }
      imported++;
    }

    return (
      imported: imported,
      tagsCreated: tagIdsByTitle.values
          .where((id) => int.tryParse(id) != null)
          .length,
      photosImported: photosImported,
      photosSkipped: photosSkipped,
    );
  }

  static Future<TagDbModel?> _findTagByTitle(String lowerTitle) async {
    final tags = await TagDbModel.db.where();
    for (final tag in tags?.items ?? []) {
      if (tag.title.trim().toLowerCase() == lowerTitle) return tag;
    }
    return null;
  }

  static Future<String> _createTag(String title) async {
    final tag = TagDbModel(
      id: TagIdGeneratorService.timeId(),
      version: 0,
      title: title,
      emoji: null,
      categoryId: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastSavedDeviceId: null,
      permanentlyDeletedAt: null,
    );
    await tag.save();
    return tag.id.toString();
  }

  /// Daylio mood titles become Feeling-category tags so they show up in the
  /// mood tracker; plain labels (Keep labels, Daylio activities, Evernote
  /// tags) stay uncategorised.
  static Future<String> _createFeelingTag(String title) async {
    final tag = TagDbModel(
      id: TagIdGeneratorService.timeId(),
      version: 0,
      title: title,
      emoji: null,
      categoryId: TagCategoryDbModel.feeling().id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastSavedDeviceId: null,
      permanentlyDeletedAt: null,
    );
    await tag.save();
    return tag.id.toString();
  }

  /// Copies matched photo temp files into asset storage, creates
  /// [AssetDbModel]s and returns markdown embed lines for the story body.
  static Future<({List<String> imported, List<String> embedLines})>
  _resolvePhotos(
    List<String> photoFileNames,
    Map<String, String> photoFiles,
  ) async {
    final imported = <String>[];
    final embedLines = <String>[];

    for (final name in photoFileNames) {
      final tempPath = photoFiles[name.toLowerCase()];
      if (tempPath == null) continue;

      final source = File(tempPath);
      if (!await source.exists()) continue;

      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.'))
          : '.jpg';
      final id = DateTime.now().millisecondsSinceEpoch + imported.length;
      final relativePath = AssetType.image.getRelativeStoragePath(
        id: id,
        extension: ext,
      );
      final storagePath = AssetType.image.getStoragePath(
        id: id,
        extension: ext,
      );

      final target = File(storagePath);
      await target.parent.create(recursive: true);
      await source.copy(target.path);

      final asset = AssetDbModel.fromLocalPath(
        id: id,
        localPath: relativePath,
        type: AssetType.image,
        createdAt: DateTime.now(),
      );
      await asset.save();

      imported.add(name);
      embedLines.add('![](images/$id$ext)');
    }

    return (imported: imported, embedLines: embedLines);
  }
}
