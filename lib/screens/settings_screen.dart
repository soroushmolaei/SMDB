import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _proxyHostController = TextEditingController();
  final _proxyPortController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    super.dispose();
  }

  void _loadIfNeeded(AppSettingsData data) {
    if (_loaded) return;
    _apiKeyController.text = data.tmdbApiKey ?? '';
    _proxyHostController.text = data.proxyHost ?? '';
    _proxyPortController.text = data.proxyPort?.toString() ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.setSetting('tmdb_api_key', _apiKeyController.text.trim());
    await db.setSetting('proxy_host', _proxyHostController.text.trim());
    await db.setSetting('proxy_port', _proxyPortController.text.trim());
    ref.invalidate(appSettingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

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
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
              const SizedBox(height: 32),
              const Text(
                'Library Folders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
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
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => ref
                                    .read(databaseProvider)
                                    .removeFolder(f.id),
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
