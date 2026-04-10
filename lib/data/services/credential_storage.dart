import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/email_config.dart';

class CredentialStorage {
  static const String _accountsKey = 'gmail_accounts_v2';
  static const String _lastActiveKey = 'last_active_account_v2';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Save a single account (adds to list or updates)
  Future<void> save(EmailConfig config) async {
    final accounts = await getAccounts();
    final existingIndex = accounts.indexWhere((a) => a.email == config.email);

    if (existingIndex >= 0) {
      accounts[existingIndex] = config;
    } else {
      accounts.add(config);
    }

    await saveAccounts(accounts);
  }

  // Save all accounts
  Future<void> saveAccounts(List<EmailConfig> accounts) async {
    final accountsJson = accounts.map((a) => a.toJsonString()).toList();
    await _storage.write(key: _accountsKey, value: accountsJson.join('|||'));
  }

  // Get all saved accounts
  Future<List<EmailConfig>> getAccounts() async {
    final accountsString = await _storage.read(key: _accountsKey);
    if (accountsString == null || accountsString.isEmpty) return [];

    try {
      final accountsList = accountsString.split('|||');
      return accountsList
          .where((s) => s.isNotEmpty)
          .map((s) => EmailConfig.fromJsonString(s))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Load single account (for backward compatibility)
  Future<EmailConfig?> load() async {
    final accounts = await getAccounts();
    if (accounts.isEmpty) return null;
    return accounts.first;
  }

  // Save last active account
  Future<void> saveLastActiveAccount(EmailConfig config) async {
    await _storage.write(key: _lastActiveKey, value: config.toJsonString());
  }

  // Get last active account
  Future<EmailConfig?> getLastActiveAccount() async {
    final lastActiveString = await _storage.read(key: _lastActiveKey);
    if (lastActiveString == null || lastActiveString.isEmpty) return null;

    try {
      return EmailConfig.fromJsonString(lastActiveString);
    } catch (e) {
      return null;
    }
  }

  // Remove a specific account
  Future<void> removeAccount(EmailConfig config) async {
    final accounts = await getAccounts();
    final updatedAccounts = accounts
        .where((a) => a.email != config.email)
        .toList();
    await saveAccounts(updatedAccounts);

    // If removed account was last active, clear it
    final lastActive = await getLastActiveAccount();
    if (lastActive?.email == config.email) {
      await _storage.delete(key: _lastActiveKey);
    }
  }

  // Clear all data
  Future<void> clear() async {
    await _storage.delete(key: _accountsKey);
    await _storage.delete(key: _lastActiveKey);
  }

  // Check if there are any saved credentials
  Future<bool> hasCredentials() async {
    final accounts = await getAccounts();
    return accounts.isNotEmpty;
  }
}
