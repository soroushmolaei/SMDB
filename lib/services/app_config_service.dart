import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// App-level configuration: API keys, proxy settings, and an optional
/// override for where the library database file lives.
///
/// Stored as a small JSON file next to the app's .exe (not inside the
/// SQLite database, and not in the Documents folder) so it survives
/// independently of the movie/show library data, and so the user can find
/// and edit/back it up easily alongside the app itself.
class AppConfig {
  final String? tmdbApiKey;
  final String? omdbApiKey;
  final String? proxyHost;
  final int? proxyPort;

  /// Folder that contains library.sqlite. Null means "use the default
  /// location" (the user's Documents folder).
  final String? databasePath;

  AppConfig({
    this.tmdbApiKey,
    this.omdbApiKey,
    this.proxyHost,
    this.proxyPort,
    this.databasePath,
  });

  Map<String, dynamic> toJson() => {
        'tmdb_api_key': tmdbApiKey,
        'omdb_api_key': omdbApiKey,
        'proxy_host': proxyHost,
        'proxy_port': proxyPort,
        'database_path': databasePath,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        tmdbApiKey: json['tmdb_api_key'] as String?,
        omdbApiKey: json['omdb_api_key'] as String?,
        proxyHost: json['proxy_host'] as String?,
        proxyPort: json['proxy_port'] as int?,
        databasePath: json['database_path'] as String?,
      );
}

class AppConfigService {
  static const String _fileName = 'smdb_config.json';

  /// The folder the running executable lives in — i.e. wherever the user
  /// extracted/placed the app, not a fixed OS folder.
  static Future<Directory> appDirectory() async {
    return File(Platform.resolvedExecutable).parent;
  }

  static Future<File> _configFile() async {
    final dir = await appDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<AppConfig> load() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return AppConfig();
      final content = await file.readAsString();
      if (content.trim().isEmpty) return AppConfig();
      return AppConfig.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return AppConfig();
    }
  }

  /// Overwrites the whole config file with [config].
  static Future<bool> save(AppConfig config) async {
    try {
      final file = await _configFile();
      await file.writeAsString(jsonEncode(config.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Updates only the given fields, preserving everything else already in
  /// the file (e.g. saving API keys must not wipe out a custom database
  /// path, and vice versa).
  static Future<bool> update({
    String? tmdbApiKey,
    String? omdbApiKey,
    String? proxyHost,
    int? proxyPort,
    bool updateProxyPort = false,
    String? databasePath,
    bool clearDatabasePath = false,
  }) async {
    final current = await load();
    final updated = AppConfig(
      tmdbApiKey: tmdbApiKey ?? current.tmdbApiKey,
      omdbApiKey: omdbApiKey ?? current.omdbApiKey,
      proxyHost: proxyHost ?? current.proxyHost,
      proxyPort:
          updateProxyPort ? proxyPort : (proxyPort ?? current.proxyPort),
      databasePath:
          clearDatabasePath ? null : (databasePath ?? current.databasePath),
    );
    return save(updated);
  }
}
