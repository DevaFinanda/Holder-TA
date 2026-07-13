import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const _localizedValues = <String, Map<String, String>>{
    'id': {
      'settings': 'Pengaturan',
      'editProfile': 'Edit Profil',
      'security': 'Keamanan',
      'language': 'Bahasa',
      'display': 'Tampilan',
      'notifications': 'Notifikasi',
      'loginHistory': 'Riwayat Login',
      'activeDevices': 'Perangkat Aktif',
      'saveChanges': 'Simpan Perubahan',
      'darkMode': 'Mode Gelap',
      'lightMode': 'Mode Terang',
      'systemMode': 'Otomatis (Sistem)',
    },
    'en': {
      'settings': 'Settings',
      'editProfile': 'Edit Profile',
      'security': 'Security',
      'language': 'Language',
      'display': 'Display',
      'notifications': 'Notifications',
      'loginHistory': 'Login History',
      'activeDevices': 'Active Devices',
      'saveChanges': 'Save Changes',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'systemMode': 'System Default',
    },
  };

  String tr(String key) {
    final lang =
        _localizedValues[locale.languageCode] ?? _localizedValues['id']!;
    return lang[key] ?? _localizedValues['id']![key] ?? key;
  }

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }
}

extension AppLocalizationExt on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
}
