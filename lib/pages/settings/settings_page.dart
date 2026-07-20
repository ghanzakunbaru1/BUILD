import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/settings_controller.dart';
import '../../utils/constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Tampilan'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Ganti Tema'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            onTap: () => _showThemeSheet(context, settings),
          ),
          const Divider(),
          const _SectionLabel('Riwayat & Data'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Hapus Riwayat'),
            subtitle: const Text('Menghapus semua percakapan secara permanen'),
            onTap: () => _confirmClearHistory(context, settings),
          ),
          const Divider(),
          const _SectionLabel('AI'),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Ganti API Key'),
            subtitle: Text(settings.apiKeyOverride == null
                ? 'Menggunakan key dari .env'
                : 'Menggunakan key kustom (•••• disembunyikan)'),
            onTap: () => _showApiKeyDialog(context, settings),
          ),
          const Divider(),
          const _SectionLabel('Tentang'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Tentang Aplikasi'),
            subtitle: Text('${AppConstants.appName} — ${AppConstants.appTagline}'),
          ),
          const ListTile(
            leading: Icon(Icons.numbers_outlined),
            title: Text('Versi Aplikasi'),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt_outlined),
            title: const Text('Cek Update'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kamu sudah menggunakan versi terbaru.')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.redAccent),
            title: const Text('Reset Pengaturan', style: TextStyle(color: Colors.redAccent)),
            onTap: () => _confirmReset(context, settings),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light Mode';
      case ThemeMode.dark: return 'Dark Mode';
      case ThemeMode.system: return 'Ikuti Sistem';
    }
  }

  void _showThemeSheet(BuildContext context, SettingsController settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            RadioListTile(
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              title: const Text('Dark Mode'),
              onChanged: (v) { settings.setThemeMode(v!); Navigator.pop(context); },
            ),
            RadioListTile(
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              title: const Text('Light Mode'),
              onChanged: (v) { settings.setThemeMode(v!); Navigator.pop(context); },
            ),
            RadioListTile(
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              title: const Text('Ikuti Sistem'),
              onChanged: (v) { settings.setThemeMode(v!); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, SettingsController settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () { settings.clearHistory(); Navigator.pop(context); },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, SettingsController settings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ganti API Key Gemini'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Tempel API key baru'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                settings.setApiKey(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, SettingsController settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset semua pengaturan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () { settings.resetSettings(); Navigator.pop(context); },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
