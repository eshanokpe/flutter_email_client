import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/email_config.dart';

class CredentialStorage {
  static const _key = 'mailflow_email_config_v2';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> save(EmailConfig config) async {
    await _storage.write(key: _key, value: config.toJsonString());
  }

  Future<EmailConfig?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return EmailConfig.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }

  Future<bool> hasCredentials() async {
    final raw = await _storage.read(key: _key);
    return raw != null;
  }
}
