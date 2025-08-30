import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/account.dart';
import '../services/account_store.dart';
import '../services/database_manager.dart';
import 'home_page.dart';
import '../services/saf_mirror_service.dart';

class AccountSetupPage extends StatefulWidget {
  const AccountSetupPage({super.key});

  @override
  State<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends State<AccountSetupPage> {
  final _nameController = TextEditingController();
  bool _saving = false;
  String? _chosenPath;
  String? _mirrorUri; // optional, when user picks a cloud provider URI

  @override
  void initState() {
    super.initState();
    _nameController.text = 'My Account';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _genId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = (Random().nextDouble() * 1e9).toInt();
    return '${now.toRadixString(16)}-${rnd.toRadixString(16)}';
  }

  Future<void> _chooseLocalRecommended() async {
    final id = _genId();
    final defaultPath = await DatabaseManager.suggestDefaultDbPath(id);
    setState(() {
      _chosenPath = defaultPath;
      _mirrorUri = null;
    });
  }

  Future<void> _chooseCustomLocationDesktop() async {
    // Let the user pick a destination for the DB file. This works best on
    // desktop where providers expose real file paths.
    final location = await fs.getSaveLocation(suggestedName: 'fine_ants.db');
    if (!mounted) return;
    // Support both older/newer file_selector: location or its path may be null.
    final path = location?.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _chosenPath = path;
      _mirrorUri =
          null; // path is a real filesystem path on supported platforms
    });
  }

  Future<void> _chooseCloudFolderMobile() async {
    // Android: use SAF via file_picker's directory picker to obtain a tree URI/path.
    // iOS: falls back to directory path when supported.
    String? directory = await FilePicker.platform.getDirectoryPath();
    if (!mounted) return;
    if (directory == null) return; // cancelled

    // On Android, directory may be a content URI like content://... Take persistable permission.
    if (Platform.isAndroid && directory.startsWith('content://')) {
      try {
        await SafMirrorService.persistPermission(directory);
        if (!mounted) return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to persist permissions: $e')),
        );
      }
      setState(() {
        _chosenPath = null;
        _mirrorUri = directory; // SAF tree URI
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud folder selected via SAF. Will mirror the DB.'),
        ),
      );
    } else {
      // A real directory path was returned (iOS or older Android). We'll copy the DB there on creation.
      setState(() {
        _chosenPath = null; // keep primary DB local by default
        _mirrorUri = directory; // treat as filesystem directory path
      });
    }
  }

  Future<void> _createAccount() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = _genId();
      String dbPath;
      if (_chosenPath == null) {
        // Fallback to recommended local path and keep mirror URI if any.
        dbPath = await DatabaseManager.suggestDefaultDbPath(id);
      } else {
        dbPath = _chosenPath!;
      }

      await DatabaseManager.createEmptyDatabaseAt(dbPath);

      final account = Account(
        id: id,
        name: name,
        dbPath: dbPath,
        mirrorUri: _mirrorUri,
        createdAt: DateTime.now(),
      );
      AccountStore.instance.accounts.add(account);
      await AccountStore.instance.save();

      // If a mirror target was chosen, write/copy the DB there once.
      try {
        if (_mirrorUri != null) {
          if (Platform.isAndroid && _mirrorUri!.startsWith('content://')) {
            final bytes = await File(dbPath).readAsBytes();
            await SafMirrorService.writeFileToTree(
              treeUri: _mirrorUri!,
              displayName: 'fine_ants.db',
              mimeType: 'application/x-sqlite3',
              bytes: bytes,
            );
          } else {
            // Filesystem directory path: copy the DB file there.
            final targetPath = p.join(_mirrorUri!, 'fine_ants.db');
            await File(dbPath).copy(targetPath);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Mirror failed: $e')));
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(account: account)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create account: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose where to save the SQLite file',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _saving ? null : _chooseLocalRecommended,
                  icon: const Icon(Icons.phone_iphone),
                  label: const Text('Use app storage (recommended)'),
                ),
                if (!Platform.isAndroid && !Platform.isIOS)
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseCustomLocationDesktop,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose file location (desktop)'),
                  ),
                if (Platform.isAndroid || Platform.isIOS)
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseCloudFolderMobile,
                    icon: const Icon(Icons.cloud),
                    label: const Text('Choose cloud folder (mobile)'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: color.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On mobile, some cloud providers return a secure URI instead of a file path. '
                    'In that case, the app will create the database locally and mirror it to the chosen location.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_chosenPath != null)
              Text(
                'Selected path: ${_chosenPath!}',
                style: theme.textTheme.bodySmall,
              ),
            if (_mirrorUri != null)
              Text(
                'Mirror URI: ${_mirrorUri!}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _createAccount,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
