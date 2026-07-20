import 'package:permission_handler/permission_handler.dart';

class AppPermission {
  final Permission permission;
  final String title;
  final String reason;
  final bool optional;

  const AppPermission({
    required this.permission,
    required this.title,
    required this.reason,
    this.optional = false,
  });
}

/// Centralized list of every permission GHANZ AI may need, with the
/// human-readable explanation shown to the user before it's requested
/// (required by the spec: "Semua permission harus dijelaskan sebelum diminta").
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  static final List<AppPermission> allPermissions = [
    const AppPermission(
      permission: Permission.camera,
      title: 'Kamera',
      reason: 'Untuk memotret dan menganalisis gambar, serta membuka kamera saat diminta.',
    ),
    const AppPermission(
      permission: Permission.microphone,
      title: 'Mikrofon',
      reason: 'Untuk fitur Voice Chat, Speech-to-Text, dan menganalisis audio.',
    ),
    const AppPermission(
      permission: Permission.photos,
      title: 'Penyimpanan / Galeri',
      reason: 'Untuk memilih gambar, file, dan dokumen yang ingin dianalisis AI.',
    ),
    const AppPermission(
      permission: Permission.notification,
      title: 'Notifikasi',
      reason: 'Untuk menampilkan reminder, timer, dan status streaming AI.',
    ),
    const AppPermission(
      permission: Permission.scheduleExactAlarm,
      title: 'Alarm & Reminder',
      reason: 'Untuk membuat alarm dan pengingat sesuai perintahmu.',
    ),
    const AppPermission(
      permission: Permission.calendarFullAccess,
      title: 'Kalender',
      reason: 'Untuk membuat dan membaca reminder/jadwal di kalender.',
      optional: true,
    ),
    const AppPermission(
      permission: Permission.contacts,
      title: 'Kontak',
      reason: 'Untuk mencari nomor saat kamu meminta "Hubungi ...".',
      optional: true,
    ),
    const AppPermission(
      permission: Permission.phone,
      title: 'Telepon',
      reason: 'Untuk melakukan panggilan telepon atas perintahmu.',
      optional: true,
    ),
    const AppPermission(
      permission: Permission.bluetoothConnect,
      title: 'Bluetooth',
      reason: 'Untuk mendeteksi & menyambungkan perangkat Bluetooth bila diperlukan.',
      optional: true,
    ),
    const AppPermission(
      permission: Permission.locationWhenInUse,
      title: 'Lokasi (Opsional)',
      reason: 'Untuk membuka Maps dengan lokasi terkini. Bisa dilewati.',
      optional: true,
    ),
  ];

  Future<PermissionStatus> request(Permission permission) {
    return permission.request();
  }

  Future<Map<Permission, PermissionStatus>> requestAll() async {
    final perms = allPermissions.map((e) => e.permission).toList();
    return perms.request();
  }

  Future<bool> isGranted(Permission permission) async {
    return permission.isGranted;
  }
}
