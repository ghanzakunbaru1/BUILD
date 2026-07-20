import 'dart:async';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

class DeviceActionResult {
  final bool success;
  final String message;
  DeviceActionResult(this.success, this.message);
}

class DeviceControlService {
  DeviceControlService._();
  static final DeviceControlService instance = DeviceControlService._();

  Timer? _flashlightTimer;

  // Flashlight
  Future<DeviceActionResult> flashlightOn({int? autoOffAfterSeconds}) async {
    try {
      await TorchLight.enableTorch();
      _flashlightTimer?.cancel();
      if (autoOffAfterSeconds != null) {
        _flashlightTimer = Timer(Duration(seconds: autoOffAfterSeconds), () {
          TorchLight.disableTorch();
        });
        return DeviceActionResult(
            true, 'Senter dinyalakan selama $autoOffAfterSeconds detik.');
      }
      return DeviceActionResult(true, 'Senter dinyalakan.');
    } catch (e) {
      return DeviceActionResult(false, 
          'Gagal menyalakan senter: perangkat tidak mendukung atau izin ditolak.');
    }
  }

  Future<DeviceActionResult> flashlightOff() async {
    try {
      _flashlightTimer?.cancel();
      await TorchLight.disableTorch();
      return DeviceActionResult(true, 'Senter dimatikan.');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal mematikan senter.');
    }
  }

  // Alarm
  Future<DeviceActionResult> setAlarm(int hour, int minute, {String? label}) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label ?? 'GHANZ AI Alarm',
          'android.intent.extra.alarm.SKIP_UI': true,
        },
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.sendBroadcast();
      final hh = hour.toString().padLeft(2, '0');
      final mm = minute.toString().padLeft(2, '0');
      return DeviceActionResult(true, 'Alarm berhasil diatur pukul $hh:$mm.');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal mengatur alarm: $e');
    }
  }

  // Open apps
  Future<DeviceActionResult> openPackage(String package, String friendlyName) async {
    try {
      final intent = AndroidIntent(
        action: 'action_main',
        package: package,
        category: 'category_launcher',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return DeviceActionResult(true, 'Membuka $friendlyName...');
    } catch (e) {
      return DeviceActionResult(
          false, '$friendlyName tidak terpasang atau gagal dibuka.');
    }
  }

  Future<DeviceActionResult> openUrl(String url, String friendlyName) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return DeviceActionResult(true, 'Membuka $friendlyName...');
    }
    return DeviceActionResult(false, 'Tidak bisa membuka $friendlyName.');
  }

  Future<DeviceActionResult> openCamera() async {
    final result = await openUrl('android-app://com.android.camera2/', 'Kamera');
    if (result.success) return result;
    return _fallbackIntent('android.media.action.IMAGE_CAPTURE', 'Kamera');
  }

  Future<DeviceActionResult> openGallery() =>
      _fallbackIntent('android.intent.action.VIEW', 'Galeri', type: 'image/*');

  Future<DeviceActionResult> _fallbackIntent(String action, String name, {String? type}) async {
    try {
      final intent = AndroidIntent(
        action: action,
        type: type,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return DeviceActionResult(true, 'Membuka $name...');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal membuka $name.');
    }
  }

  // Volume
  Future<DeviceActionResult> adjustVolume({required bool up}) async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.SOUND_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return DeviceActionResult(
        true,
        up
            ? 'Membuka pengaturan suara untuk menaikkan volume'
            : 'Membuka pengaturan suara untuk menurunkan volume.',
      );
    } catch (e) {
      return DeviceActionResult(false, 'Tidak bisa membuka pengaturan suara.');
    }
  }

  Future<DeviceActionResult> requestSilentMode() async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.NOTIFICATION_POLICY_ACCESS_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return DeviceActionResult(true,
          'Aktifkan izin "Do Not Disturb" di halaman yang terbuka.');
    } catch (e) {
      return DeviceActionResult(false, 'Tidak bisa membuka pengaturan mode senyap.');
    }
  }

  // Vibration
  Future<DeviceActionResult> vibrate(int seconds) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) {
      return DeviceActionResult(false, 'Perangkat tidak memiliki vibrator.');
    }
    await Vibration.vibrate(duration: seconds * 1000);
    return DeviceActionResult(true, 'Menggetarkan HP selama $seconds detik.');
  }

  // Brightness
  Future<DeviceActionResult> setBrightness(int percent) async {
    try {
      final status = await Permission.systemAlertWindow.status;
      if (!status.isGranted) {
        await Permission.systemAlertWindow.request();
        return DeviceActionResult(false, 
            'Izin "Modify system settings" diperlukan.');
      }
      
      await ScreenBrightness().setScreenBrightness(percent / 100);
      return DeviceActionResult(true, 'Brightness diatur ke $percent%.');
    } catch (e) {
      final intent = AndroidIntent(
        action: 'android.settings.action.MANAGE_WRITE_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return DeviceActionResult(false,
          'Perlu izin "Modify system settings". Halaman izin telah dibuka.');
    }
  }

  // Call / SMS / Email
  Future<DeviceActionResult> callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return DeviceActionResult(true, 'Membuka panggilan ke $number...');
    }
    return DeviceActionResult(false, 'Gagal membuka aplikasi telepon.');
  }

  Future<DeviceActionResult> openSms({String? number, String? body}) async {
    final uri = Uri(scheme: 'sms', path: number, 
        queryParameters: body != null ? {'body': body} : null);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return DeviceActionResult(true, 'Membuka aplikasi SMS...');
    }
    return DeviceActionResult(false, 'Gagal membuka aplikasi SMS.');
  }

  Future<DeviceActionResult> openEmail() async {
    final uri = Uri(scheme: 'mailto', path: '');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return DeviceActionResult(true, 'Membuka aplikasi Email...');
    }
    return DeviceActionResult(false, 'Gagal membuka aplikasi Email.');
  }

  // SHARE - FIXED
  Future<DeviceActionResult> shareText(String text) async {
    try {
      await Share.share(text);
      return DeviceActionResult(true, 'Membuka menu Share...');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal membuka menu share: $e');
    }
  }

  Future<DeviceActionResult> shareTextWithSubject(String text, String subject) async {
    try {
      await Share.share(text, subject: subject);
      return DeviceActionResult(true, 'Membuka menu Share...');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal membuka menu share: $e');
    }
  }

  Future<DeviceActionResult> shareFile(String path, {String? text}) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return DeviceActionResult(false, 'File tidak ditemukan: $path');
      }
      
      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: text);
      return DeviceActionResult(true, 'Membuka menu Share...');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal membuka menu share: $e');
    }
  }

  Future<DeviceActionResult> shareMultipleFiles(List<String> paths, {String? text}) async {
    try {
      final xFiles = <XFile>[];
      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) {
          return DeviceActionResult(false, 'File tidak ditemukan: $path');
        }
        xFiles.add(XFile(path));
      }
      
      await Share.shareXFiles(xFiles, text: text);
      return DeviceActionResult(true, 'Membuka menu Share...');
    } catch (e) {
      return DeviceActionResult(false, 'Gagal membuka menu share: $e');
    }
  }
}