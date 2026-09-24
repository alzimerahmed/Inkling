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
  ///
  /// When [mapMoodToFeelingTag] is true (Daylio), the entry's mood becomes a
  /// Feeling-category tag so it shows up in the mood tracker; the draft's
  /// `tags` (Daylio activities, Keep labels, Evernote tags) always become
  /// plain, uncategorised tags.
  static Future<ImportExternalResult> call({
    required List<ImportedStoryDraft> drafts,
    required Map<String, String> photoFiles,
    bool mapMoodToFeelingTag = false,
  }) async {
    int imported = 0;
    int photosImported = 0;
    int photosSkipped = 0;

    // Load all tags ONCE — a full table scan per tag title (the old
    // `_findTagByTitle`) was an N+1 on the main isolate for large imports.
    final existingTagsByTitle = <String, TagDbModel>{};
    final allTags = await TagDbModel.db.where();
    for (final tag in allTags?.items ?? []) {
      existingTagsByTitle[tag.title.trim().toLowerCase()] = tag;
    }

    final tagResolution = await resolveTagIds(
      drafts: drafts,
      existingTagsByTitle: existingTagsByTitle,
      createTag: _createTag,
      createFeelingTag: _createFeelingTag,
      mapMoodToFeelingTag: mapMoodToFeelingTag,
    );
    final tagIdsByTitle = tagResolution.idsByTitle;
    int tagsCreated = tagResolution.createdCount;

    for (final draft in drafts) {
      final tagIds = draft.tags.map((t) => tagIdsByTitle[t.trim().toLowerCase()]).whereType<String>().toList();

      // Daylio: the mood (not the activities) becomes a Feeling-category tag.
      if (mapMoodToFeelingTag && draft.feeling != null) {
        final feelingId = tagIdsByTitle[draft.feeling!.trim().toLowerCase()];
        if (feelingId != null && !tagIds.contains(feelingId)) tagIds.add(feelingId);
      }

      final resolvedPhotos = await _resolvePhotos(
        draft.photoFileNames,
        photoFiles,
      );
      photosImported += resolvedPhotos.imported.length;
      photosSkipped += draft.photoFileNames.length - resolvedPhotos.imported.length;

      final story = ImportStoryMapper.toStory(
        draft: draft,
        id: draft.date.millisecondsSinceEpoch,
        tagIds: tagIds,
        mediaPaths: resolvedPhotos.mediaPaths,
        assetIds: resolvedPhotos.assetIds,
      );

      final existing = await StoryDbModel.db.find(story.id);
      if (existing != null) {
        // Deterministic id collision (same millisecond) — shift forward until
        // free so an import never overwrites existing user data.
        int shiftedId = await shiftIdUntilFree(
          story.id,
          (id) async => await StoryDbModel.db.find(id) != null,
        );
        await StoryDbModel.db.set(
          ImportStoryMapper.toStory(
            draft: draft,
            id: shiftedId,
            tagIds: tagIds,
            mediaPaths: resolvedPhotos.mediaPaths,
            assetIds: resolvedPhotos.assetIds,
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
      tagsCreated: tagsCreated,
      photosImported: photosImported,
      photosSkipped: photosSkipped,
    );
  }

  /// Resolves every draft tag title to a tag id, creating missing tags via
  /// [createTag] (and the mood via [createFeelingTag] when
  /// [mapMoodToFeelingTag] is set). Pure with injectable callbacks so the
  /// dedup/created-count behaviour is unit-testable without ObjectBox.
  static Future<({Map<String, String> idsByTitle, int createdCount})> resolveTagIds({
    required List<ImportedStoryDraft> drafts,
    required Map<String, TagDbModel> existingTagsByTitle,
    required Future<String> Function(String title) createTag,
    required Future<String> Function(String title) createFeelingTag,
    bool mapMoodToFeelingTag = false,
  }) async {
    final idsByTitle = <String, String>{};
    int createdCount = 0;

    for (final draft in drafts) {
      for (final title in draft.tags) {
        final key = title.trim().toLowerCase();
        if (key.isEmpty || idsByTitle.containsKey(key)) continue;
        final existing = existingTagsByTitle[key];
        if (existing != null) {
          idsByTitle[key] = existing.id.toString();
        } else {
          idsByTitle[key] = await createTag(title.trim());
          createdCount++;
        }
      }

      // Daylio: the mood (not the activities) becomes a Feeling-category tag.
      if (mapMoodToFeelingTag && draft.feeling != null) {
        final feelingKey = draft.feeling!.trim().toLowerCase();
        final existingFeeling = existingTagsByTitle[feelingKey];
        if (existingFeeling != null) {
          if (!idsByTitle.containsKey(feelingKey)) idsByTitle[feelingKey] = existingFeeling.id.toString();
        } else {
          idsByTitle[feelingKey] = await createFeelingTag(
            draft.feeling!.trim(),
          );
          createdCount++;
        }
      }
    }

    return (idsByTitle: idsByTitle, createdCount: createdCount);
  }

  /// Shifts [desiredId] forward until [exists] returns false. Extracted as a
  /// pure-ish helper (injectable existence check) so the collision behaviour
  /// is unit-testable without a live ObjectBox store.
  static Future<int> shiftIdUntilFree(
    int desiredId,
    Future<bool> Function(int id) exists,
  ) async {
    int id = desiredId;
    while (await exists(id)) {
      id += 1;
    }
    return id;
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
  /// [AssetDbModel]s and returns the media embed paths + asset ids for the
  /// story body.
  static Future<({List<String> imported, List<String> mediaPaths, List<int> assetIds})> _resolvePhotos(
    List<String> photoFileNames,
    Map<String, String> photoFiles,
  ) async {
    final imported = <String>[];
    final mediaPaths = <String>[];
    final assetIds = <int>[];

    for (final name in photoFileNames) {
      final tempPath = photoFiles[name.toLowerCase()];
      if (tempPath == null) continue;

      final source = File(tempPath);
      if (!await source.exists()) continue;

      final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '.jpg';
      // Unique time-based id — `DateTime.now().millisecondsSinceEpoch + n`
      // collided for photos resolved within the same millisecond, letting
      // `asset.save()` silently overwrite an earlier AssetDbModel.
      final id = await _nextFreeAssetId();
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
      mediaPaths.add(relativePath);
      assetIds.add(id);
    }

    return (imported: imported, mediaPaths: mediaPaths, assetIds: assetIds);
  }

  /// Microsecond time id, bumped forward until no [AssetDbModel] with that id
  /// exists (guards against same-microsecond collisions in tight loops).
  static Future<int> _nextFreeAssetId() async {
    int id = TagIdGeneratorService.timeId();
    while (await AssetDbModel.db.find(id) != null) {
      id += 1;
    }
    return id;
  }
}
