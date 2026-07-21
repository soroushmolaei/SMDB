import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import '../providers/providers.dart';
import '../services/app_config_service.dart';
import '../services/omdb_service.dart';
import '../services/tmdb_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _omdbKeyController = TextEditingController();
  final _proxyHostController = TextEditingController();
  final _proxyPortController = TextEditingController();
  bool _loaded = false;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  bool _omdbTesting = false;
  String? _omdbTestResult;
  bool _omdbTestOk = false;
  bool _movingDb = false;
  String? _rescanningFolderPath;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _omdbKeyController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    super.dispose();
  }

  void _loadIfNeeded(AppSettingsData data) {
    if (_loaded) return;
    _apiKeyController.text = data.tmdbApiKey ?? '';
    _omdbKeyController.text = data.omdbApiKey ?? '';
    _proxyHostController.text = data.proxyHost ?? '';
    _proxyPortController.text = data.proxyPort?.toString() ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    final ok = await AppConfigService.update(
      tmdbApiKey: _apiKeyController.text.trim(),
      omdbApiKey: _omdbKeyController.text.trim(),
      proxyHost: _proxyHostController.text.trim(),
      proxyPort: int.tryParse(_proxyPortController.text.trim()),
      updateProxyPort: true,
    );
    ref.invalidate(appSettingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Settings saved'
                : 'Could not write settings file — is the app folder '
                    'writable?',
          ),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _testResult = 'Enter an API key first.';
        _testOk = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final proxyHost = _proxyHostController.text.trim();
    final proxyPort = int.tryParse(_proxyPortController.text.trim());
    final tmdb = TmdbService(
      apiKey: apiKey,
      proxyHost: proxyHost.isEmpty ? null : proxyHost,
      proxyPort: proxyPort,
    );

    try {
      final results = await tmdb.searchMovie('Inception');
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = true;
        _testResult = 'Connected — got ${results.length} results back from '
            'TMDB for a test search.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = e.toString();
      });
    }
  }

  Future<void> _testOmdbConnection() async {
    final apiKey = _omdbKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _omdbTestResult = 'Enter an OMDb API key first.';
        _omdbTestOk = false;
      });
      return;
    }

    setState(() {
      _omdbTesting = true;
      _omdbTestResult = null;
    });

    final proxyHost = _proxyHostController.text.trim();
    final proxyPort = int.tryParse(_proxyPortController.text.trim());
    final omdb = OmdbService(
      apiKey: apiKey,
      proxyHost: proxyHost.isEmpty ? null : proxyHost,
      proxyPort: proxyPort,
    );

    try {
      final result = await omdb.lookupMovie('Inception');
      if (!mounted) return;
      setState(() {
        _omdbTesting = false;
        _omdbTestOk = result != null;
        _omdbTestResult = result != null
            ? 'Connected — found "${result['Title']}" on a test lookup.'
            : 'Connected, but the test title was not found (unusual).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _omdbTesting = false;
        _omdbTestOk = false;
        _omdbTestResult = e.toString();
      });
    }
  }

  Future<void> _changeDatabaseLocation() async {
    final newFolder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder for the database',
    );
    if (newFolder == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move database?'),
        content: Text(
          'Copies your current library file to:\n\n$newFolder\n\n'
          'The app will switch to it right away. The old copy is left '
          'in place as a backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _moveDatabaseTo(newFolder);
  }

  Future<void> _resetDatabaseLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use default location?'),
        content: const Text(
          'Copies your current library file back to the default Documents '
          'folder and switches to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _movingDb = true);
    try {
      final oldPath = await resolveDbFilePath();
      await AppConfigService.update(clearDatabasePath: true);
      final newPath = await resolveDbFilePath();
      await _copyDbFiles(oldPath, newPath);
      ref.invalidate(databaseProvider);
      ref.invalidate(databasePathProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switched to the default location')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _movingDb = false);
    }
  }

  Future<void> _moveDatabaseTo(String newFolder) async {
    setState(() => _movingDb = true);
    try {
      final oldPath = await resolveDbFilePath();
      final newPath = p.join(newFolder, 'library.sqlite');
      await _copyDbFiles(oldPath, newPath);
      await AppConfigService.update(databasePath: newFolder);
      ref.invalidate(databaseProvider);
      ref.invalidate(databasePathProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Database moved. The old file was left in place as a backup.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move database: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _movingDb = false);
    }
  }

  Future<void> _copyDbFiles(String oldPath, String newPath) async {
    if (oldPath == newPath) return;
    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      await oldFile.copy(newPath);
    }
    for (final suffix in ['-journal', '-wal', '-shm']) {
      final companion = File('$oldPath$suffix');
      if (await companion.exists()) {
        await companion.copy('$newPath$suffix');
      }
    }
  }

  Future<void> _rescanFolder(LibraryFolder folder) async {
    setState(() => _rescanningFolderPath = folder.path);
    final controller = ref.read(scanControllerProvider.notifier);
    if (folder.type == 'movie') {
      await controller.scanMovieFolder(folder.path);
    } else {
      await controller.scanShowFolder(folder.path);
    }
    await ref.read(databaseProvider).touchFolderScanTime(folder.id);
    if (mounted) {
      setState(() => _rescanningFolderPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rescanned ${p.basename(folder.path)}')),
      );
    }
  }

  Future<void> _rescanAll(List<LibraryFolder> folders) async {
    for (final folder in folders) {
      await _rescanFolder(folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final dbPathAsync = ref.watch(databasePathProvider);
    final scanState = ref.watch(scanControllerProvider);
    final isScanning = scanState.status == ScanStatus.scanning ||
        scanState.status == ScanStatus.matching;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (data) {
          _loadIfNeeded(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'TMDB',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'TMDB API Key',
                  border: OutlineInputBorder(),
                  helperText: 'Get a free key at themoviedb.org/settings/api',
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Proxy (optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'If TMDB does not load on your network, point this at a '
                'local HTTP proxy from your VPN client.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _proxyHostController,
                decoration: const InputDecoration(
                  labelText: 'Proxy host',
                  hintText: '127.0.0.1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _proxyPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Proxy port',
                  hintText: '1080',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Connection'),
                  ),
                ],
              ),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testOk
                          ? Colors.greenAccent.shade400
                          : Colors.redAccent.shade100,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              const Text(
                'OMDb (alternative source)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Used automatically if TMDB is unreachable or finds no '
                'match. Different hosting than TMDB, so it may work even '
                'when TMDB does not.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _omdbKeyController,
                decoration: const InputDecoration(
                  labelText: 'OMDb API Key',
                  border: OutlineInputBorder(),
                  helperText: 'Get a free key at omdbapi.com/apikey.aspx',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _omdbTesting ? null : _testOmdbConnection,
                    child: _omdbTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Connection'),
                  ),
                ],
              ),
              if (_omdbTestResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _omdbTestResult!,
                    style: TextStyle(
                      color: _omdbTestOk
                          ? Colors.greenAccent.shade400
                          : Colors.redAccent.shade100,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'TMDB key, OMDb key, and proxy are saved in smdb_config.json '
                'next to the app, not inside the database file.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 32),
              const Text(
                'Database',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Where your movie/show library file (library.sqlite) is '
                'stored. Defaults to your Documents folder.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              dbPathAsync.when(
                data: (path) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    path,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _movingDb ? null : _changeDatabaseLocation,
                    icon: _movingDb
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open, size: 16),
                    label: const Text('Change Location...'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _movingDb ? null : _resetDatabaseLocation,
                    child: const Text('Use Default'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Text(
                    'Library Folders',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  foldersAsync.maybeWhen(
                    data: (folders) => folders.isEmpty
                        ? const SizedBox.shrink()
                        : TextButton.icon(
                            onPressed:
                                isScanning ? null : () => _rescanAll(folders),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Rescan All'),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Added a new movie or episode to a folder you already '
                'scanned? Rescan it instead of re-adding the whole folder.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (isScanning)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                    value: scanState.total > 0
                        ? scanState.processed / scanState.total
                        : null,
                  ),
                ),
              foldersAsync.when(
                data: (folders) {
                  if (folders.isEmpty) {
                    return const Text(
                      'No folders added yet.',
                      style: TextStyle(color: Colors.white54),
                    );
                  }
                  return Column(
                    children: folders
                        .map((f) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                f.type == 'movie'
                                    ? Icons.movie_outlined
                                    : Icons.tv_outlined,
                              ),
                              title: Text(f.path),
                              subtitle: Text(f.type),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _rescanningFolderPath == f.path
                                      ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2),
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.refresh),
                                          tooltip: 'Rescan this folder',
                                          onPressed: isScanning
                                              ? null
                                              : () => _rescanFolder(f),
                                        ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove folder',
                                    onPressed: () => ref
                                        .read(databaseProvider)
                                        .removeFolder(f.id),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
