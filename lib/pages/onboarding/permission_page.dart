import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_colors.dart';

class PermissionPage extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionPage({super.key, required this.onDone});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  final Map<Permission, bool> _granted = {};
  bool _requesting = false;

  Future<void> _requestOne(AppPermission ap) async {
    final status = await PermissionService.instance.request(ap.permission);
    setState(() => _granted[ap.permission] = status.isGranted);
  }

  Future<void> _requestAll() async {
    setState(() => _requesting = true);
    final results = await PermissionService.instance.requestAll();
    setState(() {
      _granted.addAll(results.map((k, v) => MapEntry(k, v.isGranted)));
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final perms = PermissionService.allPermissions;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (b) => AppColors.neonGradient.createShader(b),
                child: const Text(
                  'Izin Aplikasi',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'GHANZ AI membutuhkan beberapa izin agar bisa membantu secara maksimal. '
                'Berikut penjelasan tiap izin sebelum kamu memberikannya:',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: perms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final ap = perms[i];
                    final granted = _granted[ap.permission] ?? false;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Icon(
                          granted ? Icons.check_circle : Icons.privacy_tip_outlined,
                          color: granted ? AppColors.success : AppColors.neonBlue,
                        ),
                        title: Text(ap.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(ap.reason, style: const TextStyle(fontSize: 12.5)),
                        trailing: TextButton(
                          onPressed: () => _requestOne(ap),
                          child: Text(granted ? 'OK' : (ap.optional ? 'Opsional' : 'Izinkan')),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _requesting ? null : _requestAll,
                  child: _requesting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Izinkan Semua'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onDone,
                  child: const Text('Lanjutkan'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
