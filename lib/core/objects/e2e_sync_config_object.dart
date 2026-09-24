/// Opt-in E2E-encrypted sync configuration (Gap #12). Stored in secure
/// storage alongside the other cloud credentials. `enabled` defaults to
/// false — sync never runs unless the user explicitly turns it on.
class E2eSyncConfigObject {
  final String serverUrl;
  final String username;
  final String appPassword;

  /// WebDAV folder (relative to the account root) the encrypted payload is
  /// written to. Defaults to [defaultFolderName].
  final String? folderName;

  /// Base64 PBKDF2 salt for the passphrase-derived key. Generated once at
  /// first enable and persisted — re-deriving the key on another device with
  /// the same passphrase requires this salt to travel with the config.
  final String saltB64;

  final bool enabled;

  /// ISO-8601 timestamp of the last successful "Sync now", or null.
  final String? lastSyncedAtIso;

  static const String defaultFolderName = 'InklingE2ESync';

  const E2eSyncConfigObject({
    required this.serverUrl,
    required this.username,
    required this.appPassword,
    required this.saltB64,
    this.folderName,
    this.enabled = false,
    this.lastSyncedAtIso,
  });

  E2eSyncConfigObject copyWith({
    String? serverUrl,
    String? username,
    String? appPassword,
    String? folderName,
    String? saltB64,
    bool? enabled,
    String? lastSyncedAtIso,
    bool clearLastSyncedAt = false,
  }) {
    return E2eSyncConfigObject(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      appPassword: appPassword ?? this.appPassword,
      folderName: folderName ?? this.folderName,
      saltB64: saltB64 ?? this.saltB64,
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
      folderName: json['folderName'] as String?,
      saltB64: json['saltB64'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      lastSyncedAtIso: json['lastSyncedAtIso'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'appPassword': appPassword,
        'folderName': folderName,
        'saltB64': saltB64,
        'enabled': enabled,
        'lastSyncedAtIso': lastSyncedAtIso,
      };
}
