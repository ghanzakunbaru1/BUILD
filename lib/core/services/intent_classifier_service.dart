/// The kind of action GHANZ AI should take for a given user message.
enum DeviceIntent {
  none, // Normal chat -> goes to Gemini
  setAlarm,
  flashlightOn,
  flashlightOff,
  openWhatsApp,
  openTelegram,
  openInstagram,
  openTikTok,
  openYoutube,
  openCamera,
  openGallery,
  openMaps,
  openChrome,
  volumeUp,
  volumeDown,
  silentMode,
  vibrate,
  setBrightness,
  setTimer,
  setReminder,
  callContact,
  sendSms,
  openEmail,
  scanQr,
  shareFile,
}

class ClassifiedIntent {
  final DeviceIntent intent;
  final Map<String, dynamic> params;
  ClassifiedIntent(this.intent, [this.params = const {}]);
}

/// Lightweight, offline, keyword-based classifier for Indonesian & English
/// commands. Runs instantly before falling back to Gemini for anything
/// that isn't clearly a device command, so the app stays responsive even
/// without a network round-trip for simple actions like "nyalakan senter".
class IntentClassifierService {
  IntentClassifierService._();
  static final IntentClassifierService instance = IntentClassifierService._();

  ClassifiedIntent classify(String rawMessage) {
    final msg = rawMessage.toLowerCase().trim();

    // --- Alarm ---
    final alarmMatch = RegExp(r'(setel|pasang|buat)\s+alarm.*?(\d{1,2})[:.](\d{2})')
        .firstMatch(msg);
    if (alarmMatch != null) {
      final hour = int.parse(alarmMatch.group(2)!);
      final minute = int.parse(alarmMatch.group(3)!);
      return ClassifiedIntent(
          DeviceIntent.setAlarm, {'hour': hour, 'minute': minute});
    }

    // --- Flashlight ---
    if (RegExp(r'(nyalakan|hidupkan|on).*(senter|flash(light)?)').hasMatch(msg)) {
      final durMatch = RegExp(r'(\d+)\s*detik').firstMatch(msg);
      final seconds = durMatch != null ? int.parse(durMatch.group(1)!) : null;
      return ClassifiedIntent(DeviceIntent.flashlightOn, {'seconds': seconds});
    }
    if (RegExp(r'(matikan|off).*(senter|flash(light)?)').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.flashlightOff);
    }

    // --- Open apps ---
    if (_containsOpen(msg, ['whatsapp'])) return ClassifiedIntent(DeviceIntent.openWhatsApp);
    if (_containsOpen(msg, ['telegram'])) return ClassifiedIntent(DeviceIntent.openTelegram);
    if (_containsOpen(msg, ['instagram', 'ig'])) return ClassifiedIntent(DeviceIntent.openInstagram);
    if (_containsOpen(msg, ['tiktok'])) return ClassifiedIntent(DeviceIntent.openTikTok);
    if (_containsOpen(msg, ['youtube', 'yt'])) return ClassifiedIntent(DeviceIntent.openYoutube);
    if (_containsOpen(msg, ['kamera', 'camera'])) return ClassifiedIntent(DeviceIntent.openCamera);
    if (_containsOpen(msg, ['galeri', 'gallery'])) return ClassifiedIntent(DeviceIntent.openGallery);
    if (_containsOpen(msg, ['maps', 'peta'])) return ClassifiedIntent(DeviceIntent.openMaps);
    if (_containsOpen(msg, ['chrome', 'browser'])) return ClassifiedIntent(DeviceIntent.openChrome);
    if (_containsOpen(msg, ['email', 'gmail'])) return ClassifiedIntent(DeviceIntent.openEmail);

    // --- Volume ---
    if (RegExp(r'(naikkan|tambah).*volume').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.volumeUp);
    }
    if (RegExp(r'(turunkan|kecilkan|kurangi).*volume').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.volumeDown);
    }
    if (RegExp(r'(mode\s*senyap|silent\s*mode|mode\s*diam)').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.silentMode);
    }

    // --- Vibrate ---
    final vibMatch = RegExp(r'getar(kan)?.*?(\d+)?\s*detik').firstMatch(msg);
    if (vibMatch != null || msg.contains('getarkan')) {
      final seconds = vibMatch?.group(2) != null ? int.parse(vibMatch!.group(2)!) : 2;
      return ClassifiedIntent(DeviceIntent.vibrate, {'seconds': seconds});
    }

    // --- Brightness ---
    final brightMatch = RegExp(r'brightness.*?(\d{1,3})\s*persen').firstMatch(msg);
    if (brightMatch != null) {
      final percent = int.parse(brightMatch.group(1)!).clamp(0, 100);
      return ClassifiedIntent(DeviceIntent.setBrightness, {'percent': percent});
    }

    // --- Timer ---
    final timerMatch = RegExp(r'(buat|pasang)\s+timer.*?(\d+)\s*(menit|detik|jam)')
        .firstMatch(msg);
    if (timerMatch != null) {
      final value = int.parse(timerMatch.group(2)!);
      final unit = timerMatch.group(3)!;
      final seconds = unit.startsWith('jam')
          ? value * 3600
          : unit.startsWith('menit')
              ? value * 60
              : value;
      return ClassifiedIntent(DeviceIntent.setTimer, {'seconds': seconds});
    }

    // --- Reminder ---
    if (RegExp(r'(buat|pasang|ingatkan).*(reminder|pengingat)').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.setReminder, {'raw': rawMessage});
    }

    // --- Call ---
    final callMatch = RegExp(r'(hubungi|telepon|call)\s+(.+)').firstMatch(msg);
    if (callMatch != null) {
      return ClassifiedIntent(DeviceIntent.callContact, {'name': callMatch.group(2)});
    }

    // --- SMS ---
    if (RegExp(r'(kirim|buka)\s*sms').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.sendSms);
    }

    // --- QR ---
    if (RegExp(r'scan\s*qr|pindai\s*qr').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.scanQr);
    }

    // --- Share ---
    if (RegExp(r'bagikan\s*file|share\s*file').hasMatch(msg)) {
      return ClassifiedIntent(DeviceIntent.shareFile);
    }

    return ClassifiedIntent(DeviceIntent.none);
  }

  bool _containsOpen(String msg, List<String> targets) {
    final hasOpenWord = RegExp(r'\b(buka|open|jalankan)\b').hasMatch(msg);
    if (!hasOpenWord) return false;
    return targets.any((t) => msg.contains(t));
  }
}
