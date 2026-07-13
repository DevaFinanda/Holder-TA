import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';

class AppSettingsProvider with ChangeNotifier {
  static const _keyLanguage = 'settings.language';
  static const _keyThemeMode = 'settings.themeMode';
  static const _keyFontScale = 'settings.fontScale';
  static const _keyHighContrast = 'settings.highContrast';

  static const _keyPushNotifications = 'settings.notif.push';
  static const _keyEmailNotifications = 'settings.notif.email';
  static const _keySmsNotifications = 'settings.notif.sms';
  static const _keyCredentialUpdates = 'settings.notif.credentialUpdates';
  static const _keySecurityAlerts = 'settings.notif.securityAlerts';
  static const _keyTransactionNotif = 'settings.notif.transaction';
  static const _keyPromotions = 'settings.notif.promotions';

  static const _keyBiometricEnabled = 'settings.security.biometric';
  static const _keyPinEnabled = 'settings.security.pinEnabled';
  static const _keyTwoFactorEnabled = 'settings.security.twoFactor';

  bool _isReady = false;

  String _languageCode = 'id';
  String _themeMode = 'light';
  double _fontScale = 1.0;
  bool _highContrast = false;

  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _credentialUpdates = true;
  bool _securityAlerts = true;
  bool _transactionNotif = true;
  bool _promotions = false;

  bool _biometricEnabled = true;
  bool _pinEnabled = true;
  bool _twoFactorEnabled = false;
  String? _pinCode;

  bool get isReady => _isReady;

  String get languageCode => _languageCode;
  String get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;

  bool get pushNotifications => _pushNotifications;
  bool get emailNotifications => _emailNotifications;
  bool get smsNotifications => _smsNotifications;
  bool get credentialUpdates => _credentialUpdates;
  bool get securityAlerts => _securityAlerts;
  bool get transactionNotif => _transactionNotif;
  bool get promotions => _promotions;

  bool get biometricEnabled => _biometricEnabled;
  bool get pinEnabled => _pinEnabled;
  bool get twoFactorEnabled => _twoFactorEnabled;
  String? get pinCode => _pinCode;

  ThemeMode get themeModeValue {
    switch (_themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'auto':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Locale get localeValue {
    switch (_languageCode) {
      case 'en':
        return const Locale('en');
      default:
        return const Locale('id');
    }
  }

  AppSettingsProvider() {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _languageCode = prefs.getString(_keyLanguage) ?? _languageCode;
    _themeMode = prefs.getString(_keyThemeMode) ?? _themeMode;
    _fontScale = prefs.getDouble(_keyFontScale) ?? _fontScale;
    _highContrast = prefs.getBool(_keyHighContrast) ?? _highContrast;

    _pushNotifications =
        prefs.getBool(_keyPushNotifications) ?? _pushNotifications;
    _emailNotifications =
        prefs.getBool(_keyEmailNotifications) ?? _emailNotifications;
    _smsNotifications =
        prefs.getBool(_keySmsNotifications) ?? _smsNotifications;
    _credentialUpdates =
        prefs.getBool(_keyCredentialUpdates) ?? _credentialUpdates;
    _securityAlerts = prefs.getBool(_keySecurityAlerts) ?? _securityAlerts;
    _transactionNotif =
        prefs.getBool(_keyTransactionNotif) ?? _transactionNotif;
    _promotions = prefs.getBool(_keyPromotions) ?? _promotions;

    _biometricEnabled =
        prefs.getBool(_keyBiometricEnabled) ?? _biometricEnabled;
    _pinEnabled = prefs.getBool(_keyPinEnabled) ?? _pinEnabled;
    _twoFactorEnabled =
        prefs.getBool(_keyTwoFactorEnabled) ?? _twoFactorEnabled;
    _pinCode = await SecureStorageService.loadPinCode();

    _isReady = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String value) async {
    _languageCode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, value);
    notifyListeners();
  }

  Future<void> setThemeMode(String value) async {
    _themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, value);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontScale, value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighContrast, value);
    notifyListeners();
  }

  Future<void> setPushNotifications(bool value) async {
    _pushNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushNotifications, value);
    notifyListeners();
  }

  Future<void> setEmailNotifications(bool value) async {
    _emailNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailNotifications, value);
    notifyListeners();
  }

  Future<void> setSmsNotifications(bool value) async {
    _smsNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySmsNotifications, value);
    notifyListeners();
  }

  Future<void> setCredentialUpdates(bool value) async {
    _credentialUpdates = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCredentialUpdates, value);
    notifyListeners();
  }

  Future<void> setSecurityAlerts(bool value) async {
    _securityAlerts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecurityAlerts, value);
    notifyListeners();
  }

  Future<void> setTransactionNotif(bool value) async {
    _transactionNotif = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTransactionNotif, value);
    notifyListeners();
  }

  Future<void> setPromotions(bool value) async {
    _promotions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPromotions, value);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, value);
    notifyListeners();
  }

  Future<void> setPin({required bool enabled, String? pinCode}) async {
    _pinEnabled = enabled;
    _pinCode = pinCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPinEnabled, enabled);
    if (pinCode != null && pinCode.isNotEmpty) {
      await SecureStorageService.savePinCode(pinCode);
    } else {
      await SecureStorageService.clearPinCode();
    }
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    if (_pinCode == null || _pinCode!.isEmpty) return false;
    return _pinCode == pin;
  }

  Future<void> setTwoFactorEnabled(bool value) async {
    _twoFactorEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTwoFactorEnabled, value);
    notifyListeners();
  }

  String languageLabel([String localeCode = 'id']) {
    final isEnglish = localeCode == 'en';
    switch (_languageCode) {
      case 'en':
        return 'English';
      case 'jv':
        return isEnglish ? 'Javanese' : 'Basa Jawa';
      case 'su':
        return isEnglish ? 'Sundanese' : 'Basa Sunda';
      default:
        return isEnglish ? 'Indonesian' : 'Indonesia';
    }
  }

  String themeLabel([String localeCode = 'id']) {
    final isEnglish = localeCode == 'en';
    switch (_themeMode) {
      case 'dark':
        return isEnglish ? 'Dark Mode' : 'Mode Gelap';
      case 'auto':
        return isEnglish ? 'System' : 'Otomatis';
      default:
        return isEnglish ? 'Light Mode' : 'Mode Terang';
    }
  }
}
