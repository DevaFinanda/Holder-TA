import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/oid4vci_service.dart';
import '../services/secure_storage_service.dart';

class LoginHistoryItem {
  final DateTime timestamp;
  final bool success;
  final String method;
  final String device;

  LoginHistoryItem({
    required this.timestamp,
    required this.success,
    required this.method,
    required this.device,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'method': method,
      'device': device,
    };
  }

  factory LoginHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoginHistoryItem(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      success: json['success'] == true,
      method: json['method']?.toString() ?? 'password',
      device: json['device']?.toString() ?? defaultTargetPlatform.name,
    );
  }
}

class _StoredAccount {
  final UserModel user;
  final String password;

  _StoredAccount({
    required this.user,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
    };
  }

  factory _StoredAccount.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    final userMap = userRaw is Map<String, dynamic>
        ? userRaw
        : Map<String, dynamic>.from(userRaw as Map);

    return _StoredAccount(
      user: UserModel.fromJson(userMap),
      password: json['password']?.toString() ?? '',
    );
  }

  _StoredAccount copyWith({
    UserModel? user,
    String? password,
  }) {
    return _StoredAccount(
      user: user ?? this.user,
      password: password ?? this.password,
    );
  }
}

class AuthProvider with ChangeNotifier {
  static const _historyKey = 'auth.loginHistory';
  static const _accountsKey = 'auth.accounts.v1';
  static const _activeAccountIdKey = 'auth.activeAccountId';

  static const _isLoggedInKey = 'isLoggedIn';
  static const _wasLoggedInBeforeKey = 'wasLoggedInBefore';
  static const _legacyUserIdKey = 'userId';
  static const _legacyUserNameKey = 'userName';
  static const _legacyUserEmailKey = 'userEmail';
  static const _legacyUserNikKey = 'userNik';
  static const _legacyUserPhoneKey = 'userPhone';
  static const _legacyUserAddressKey = 'userAddress';
  static const _legacyUserPhotoUrlKey = 'userPhotoUrl';
  static const _legacyUserPasswordKey = 'userPassword';

  UserModel? _currentUser;
  String? _currentAccountPassword;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  List<LoginHistoryItem> _loginHistory = [];

  UserModel? get currentUser => _currentUser;
  String? get currentAccountPassword => _currentAccountPassword;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  List<LoginHistoryItem> get loginHistory => List.unmodifiable(_loginHistory);

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await SecureStorageService.purgeLegacyGlobalHolderIdentity();
    final accounts = await _loadAccounts(prefs);
    await _clearLegacySessionKeys(prefs);

    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    if (_isLoggedIn) {
      final activeAccountId = prefs.getString(_activeAccountIdKey);
      final account = _findAccountById(accounts, activeAccountId);
      if (account != null) {
        _currentUser = account.user;
        _currentAccountPassword = await _resolveAccountPassword(account) ?? '';
        await SecureStorageService.setStorageScope(account.user.id);
        OID4VCIService.reset();
        OID4VCIService.setActiveIdentityUser(account.user.id);
        await OID4VCIService.ensureHolderDid(userId: account.user.id);
      } else {
        _isLoggedIn = false;
        _currentUser = null;
        _currentAccountPassword = null;
        await prefs.setBool(_isLoggedInKey, false);
      }
    }

    if (!_isLoggedIn) {
      _currentUser = null;
      _currentAccountPassword = null;
      OID4VCIService.reset();
      await SecureStorageService.setStorageScope(null);
    }

    await prefs.setBool(_wasLoggedInBeforeKey, accounts.isNotEmpty);

    final encodedHistory = prefs.getString(_historyKey);
    if (encodedHistory != null && encodedHistory.isNotEmpty) {
      try {
        final decoded = jsonDecode(encodedHistory) as List<dynamic>;
        _loginHistory = decoded
            .map((item) =>
                LoginHistoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _loginHistory = [];
      }
    }

    notifyListeners();
  }

  Future<void> _recordLoginEvent({
    required bool success,
    required String method,
  }) async {
    final item = LoginHistoryItem(
      timestamp: DateTime.now(),
      success: success,
      method: method,
      device: defaultTargetPlatform.name,
    );

    _loginHistory = [item, ..._loginHistory].take(30).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(_loginHistory.map((entry) => entry.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (email.isNotEmpty && password.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _loadAccounts(prefs);
      final account = _findAccountByEmail(accounts, email.trim());

      final storedPassword =
          account == null ? null : await _resolveAccountPassword(account);

      if (account == null || storedPassword != password) {
        await _recordLoginEvent(success: false, method: 'password');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _applySession(
        prefs,
        account,
        isLoggedIn: true,
      );

      await _recordLoginEvent(success: true, method: 'password');

      _isLoading = false;
      notifyListeners();
      return true;
    }

    await _recordLoginEvent(success: false, method: 'password');
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String name, String email, String password,
      [String nik = '']) async {
    _isLoading = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _loadAccounts(prefs);
      final normalizedEmail = email.trim();
      final existing = _findAccountByEmail(accounts, normalizedEmail);

      if (existing != null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final account = _StoredAccount(
        user: UserModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          email: normalizedEmail,
          nik: nik.trim(),
        ),
        password: password,
      );

      await SecureStorageService.saveAccountPassword(
        userId: account.user.id,
        password: password,
      );
      accounts.add(account.copyWith(password: ''));
      await _saveAccounts(prefs, accounts);
      await _applySession(prefs, account, isLoggedIn: true);
      await _recordLoginEvent(success: true, method: 'register');

      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _recordLoginEvent(success: true, method: 'logout');
    await _clearSessionData();
  }

  Future<void> resetSessionOnAppExit() async {
    await _clearSessionData(notify: false);
  }

  Future<void> _clearSessionData({bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    final accounts = await _loadAccounts(prefs);
    await prefs.setBool(_wasLoggedInBeforeKey, accounts.isNotEmpty);
    OID4VCIService.reset();
    await SecureStorageService.setStorageScope(null);

    _currentUser = null;
    _currentAccountPassword = null;
    _isLoggedIn = false;
    _isLoading = false;

    if (notify) {
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
  }) async {
    if (_currentUser == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccounts(prefs);
    final index = accounts.indexWhere((a) => a.user.id == _currentUser!.id);
    if (index < 0) return false;

    final updated = UserModel(
      id: _currentUser!.id,
      name: name,
      email: email,
      nik: _currentUser!.nik,
      photoUrl: _currentUser!.photoUrl,
      phone: phone,
      address: address,
    );

    accounts[index] = accounts[index].copyWith(user: updated);
    await _saveAccounts(prefs, accounts);
    await _applySession(
      prefs,
      accounts[index],
      isLoggedIn: _isLoggedIn,
    );

    notifyListeners();
    return true;
  }

  Future<bool> updatePhoto(String photoPath) async {
    if (_currentUser == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccounts(prefs);
    final index = accounts.indexWhere((a) => a.user.id == _currentUser!.id);
    if (index < 0) return false;

    final updated = UserModel(
      id: _currentUser!.id,
      name: _currentUser!.name,
      email: _currentUser!.email,
      nik: _currentUser!.nik,
      photoUrl: photoPath,
      phone: _currentUser!.phone,
      address: _currentUser!.address,
    );

    accounts[index] = accounts[index].copyWith(user: updated);
    await _saveAccounts(prefs, accounts);
    await _applySession(
      prefs,
      accounts[index],
      isLoggedIn: _isLoggedIn,
    );

    notifyListeners();
    return true;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccounts(prefs);
    if (_currentUser == null) return false;

    final index = accounts.indexWhere((a) => a.user.id == _currentUser!.id);
    if (index < 0) return false;

    final savedPassword = await _resolveAccountPassword(accounts[index]) ?? '';

    if (savedPassword.isNotEmpty && savedPassword != currentPassword) {
      return false;
    }

    await SecureStorageService.saveAccountPassword(
      userId: accounts[index].user.id,
      password: newPassword,
    );
    accounts[index] = accounts[index].copyWith(password: '');
    await _saveAccounts(prefs, accounts);
    await _applySession(
      prefs,
      accounts[index],
      isLoggedIn: _isLoggedIn,
    );

    return true;
  }

  Future<bool> loginWithBiometric() async {
    _isLoading = true;
    notifyListeners();

    // Simulate biometric authentication
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccounts(prefs);
    final activeId = prefs.getString(_activeAccountIdKey);
    final account = _findAccountById(accounts, activeId) ??
        (accounts.isNotEmpty ? accounts.first : null);
    final canLogin = account != null;

    if (canLogin) {
      await _applySession(
        prefs,
        account,
        isLoggedIn: true,
      );
    }

    await _recordLoginEvent(
      success: canLogin,
      method: 'biometric',
    );

    _isLoading = false;
    notifyListeners();
    return canLogin;
  }

  Future<List<_StoredAccount>> _loadAccounts(SharedPreferences prefs) async {
    final raw = prefs.getString(_accountsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final accounts = decoded
            .whereType<Map>()
            .map((entry) =>
                _StoredAccount.fromJson(Map<String, dynamic>.from(entry)))
            .toList();

        var migrated = false;
        for (var i = 0; i < accounts.length; i++) {
          final account = accounts[i];
          if (account.password.isNotEmpty) {
            await SecureStorageService.saveAccountPassword(
              userId: account.user.id,
              password: account.password,
            );
            accounts[i] = account.copyWith(password: '');
            migrated = true;
          }
        }

        if (migrated) {
          await _saveAccounts(prefs, accounts);
        }

        return accounts;
      } catch (_) {
        // Ignore parse errors and fallback to legacy migration.
      }
    }

    return _migrateLegacyAccountIfNeeded(prefs);
  }

  Future<List<_StoredAccount>> _migrateLegacyAccountIfNeeded(
      SharedPreferences prefs) async {
    final legacyEmail = prefs.getString(_legacyUserEmailKey) ?? '';
    if (legacyEmail.isEmpty) {
      return [];
    }

    final migrated = _StoredAccount(
      user: UserModel(
        id: prefs.getString(_legacyUserIdKey) ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: prefs.getString(_legacyUserNameKey) ?? '',
        email: legacyEmail,
        nik: prefs.getString(_legacyUserNikKey) ?? '',
        photoUrl: prefs.getString(_legacyUserPhotoUrlKey),
        phone: prefs.getString(_legacyUserPhoneKey),
        address: prefs.getString(_legacyUserAddressKey),
      ),
      password: prefs.getString(_legacyUserPasswordKey) ?? '',
    );

    if (migrated.password.isNotEmpty) {
      await SecureStorageService.saveAccountPassword(
        userId: migrated.user.id,
        password: migrated.password,
      );
    }

    final accounts = [migrated.copyWith(password: '')];
    await _saveAccounts(prefs, accounts);
    await _clearLegacySessionKeys(prefs);
    return accounts;
  }

  Future<void> _saveAccounts(
    SharedPreferences prefs,
    List<_StoredAccount> accounts,
  ) async {
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  _StoredAccount? _findAccountByEmail(
      List<_StoredAccount> accounts, String email) {
    final lookup = email.trim().toLowerCase();
    if (lookup.isEmpty) return null;

    for (final account in accounts) {
      if (account.user.email.trim().toLowerCase() == lookup) {
        return account;
      }
    }
    return null;
  }

  _StoredAccount? _findAccountById(List<_StoredAccount> accounts, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final account in accounts) {
      if (account.user.id == id) {
        return account;
      }
    }
    return null;
  }

  Future<void> _applySession(
    SharedPreferences prefs,
    _StoredAccount account, {
    required bool isLoggedIn,
  }) async {
    _currentUser = account.user;
    _currentAccountPassword = await _resolveAccountPassword(account);
    _isLoggedIn = isLoggedIn;

    await prefs.setBool(_isLoggedInKey, isLoggedIn);
    await prefs.setBool(_wasLoggedInBeforeKey, true);
    await prefs.setString(_activeAccountIdKey, account.user.id);
    await _clearLegacySessionKeys(prefs);
    await SecureStorageService.purgeLegacyGlobalHolderIdentity();
    await SecureStorageService.setStorageScope(account.user.id);
    OID4VCIService.reset();
    OID4VCIService.setActiveIdentityUser(account.user.id);

    // Enforce per-user holder identity bootstrap on every login session.
    try {
      await OID4VCIService.ensureHolderDid(userId: account.user.id);
    } catch (e) {
      debugPrint('[AuthProvider] Holder DID bootstrap failed: $e');
      rethrow;
    }
  }

  Future<void> _clearLegacySessionKeys(SharedPreferences prefs) async {
    await prefs.remove(_legacyUserIdKey);
    await prefs.remove(_legacyUserNameKey);
    await prefs.remove(_legacyUserEmailKey);
    await prefs.remove(_legacyUserNikKey);
    await prefs.remove(_legacyUserPasswordKey);
    await prefs.remove(_legacyUserPhoneKey);
    await prefs.remove(_legacyUserAddressKey);
    await prefs.remove(_legacyUserPhotoUrlKey);
  }

  Future<String?> _resolveAccountPassword(_StoredAccount account) async {
    final stored =
        await SecureStorageService.loadAccountPassword(account.user.id);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    if (account.password.isNotEmpty) {
      await SecureStorageService.saveAccountPassword(
        userId: account.user.id,
        password: account.password,
      );
      return account.password;
    }
    return null;
  }
}
