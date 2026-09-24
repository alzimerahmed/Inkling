import 'package:storypad/core/objects/e2e_sync_config_object.dart';
import 'package:storypad/core/storages/base_object_storages/object_storage.dart';
import 'package:storypad/core/storages/storage_adapters/base_storage_adapter.dart';
import 'package:storypad/core/storages/storage_adapters/secure_storage_adaptor.dart';

/// Secure storage for the E2E sync configuration (server URL, credentials,
/// key-derivation salt, opt-in flag, last-sync timestamp).
class E2eSyncConfigStorage extends ObjectStorage<E2eSyncConfigObject> {
  @override
  Future<BaseStorageAdapter<String>> get adapter async => SecureStorageAdaptor();

  @override
  E2eSyncConfigObject decode(Map<String, dynamic> json) => E2eSyncConfigObject.fromJson(json);

  @override
  Map<String, dynamic> encode(E2eSyncConfigObject object) => object.toJson();
}
