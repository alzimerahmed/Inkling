/// Opt-in E2E-encrypted sync configuration (Gap #12). Stored in secure
/// storage alongside the other cloud credentials. `enabled` defaults to
/// false — sync never runs unless the user explicitly turns it on.
///
/// The [passphrase] is stored here (secure storage) so "Sync now" works
/// across app restarts; it never leaves the device except as a PBKDF2
/// key inside [E2eEncryptionService], and is never logged.
class E2eSyncConfigObject {
  final String serverUrl;
  final String username;
  final String appPassword;

  /// Encryption passphrase for the client-side E2E layer.
  final String passphrase;

  /// WebDAV folder (relative to the account root) the encrypted payload is
  /// written to. Defaults to [defaultFolderName].
  final String? folderName;

  final bool enabled;

  /// ISO-8601 timestamp of the last successful "Sync now", or null.
  final String? lastSyncedAtIso;

  static const String defaultFolderName = 'InklingE2ESync';

  const E2eSyncConfigObject({
    required this.serverUrl,
    required this.username,
    required this.appPassword,
    required this.passphrase,
    this.folderName,
    this.enabled = false,
    this.lastSyncedAtIso,
  });

  E2eSyncConfigObject copyWith({
    String? serverUrl,
    String? username,
    String? appPassword,
    String? passphrase,
    String? folderName,
    bool? enabled,
    String? lastSyncedAtIso,
    bool clearLastSyncedAt = false,
  }) {
    return E2eSyncConfigObject(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      appPassword: appPassword ?? this.appPassword,
      passphrase: passphrase ?? this.passphrase,
      folderName: folderName ?? this.folderName,
      enabled: enabled ?? this.enabled,
      lastSyncedAtIso: clearLastSyncedAt ? null : (lastSyncedAtIso ?? this.lastSyncedAtIso),
    );
  }

  DateTime? get lastSyncedAt => lastSyncedAtIso == null ? null : DateTime.tryParse(lastSyncedAtIso!);

  factory E2eSyncConfigObject.fromJson(Map<String, dynamic> json) {
    return E2eSyncConfigObject(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      appPassword: json['appPassword'] as String? ?? '',
      passphrase: json['passphrase'] as String? ?? '',
      folderName: json['folderName'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      lastSyncedAtIso: json['lastSyncedAtIso'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'appPassword': appPassword,
    'passphrase': passphrase,
    'folderName': folderName,
    'enabled': enabled,
    'lastSyncedAtIso': lastSyncedAtIso,
  };
}
