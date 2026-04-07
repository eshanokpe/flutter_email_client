import '../models/email_model.dart';
import '../models/email_config.dart';
import '../services/gmail_service.dart';
import '../services/credential_storage.dart';

// ─── Email repository ─────────────────────────────────────────────────────────

abstract class IEmailRepository {
  Future<List<EmailModel>> getEmails({String folder, int pageSize});
  Future<EmailModel?> getEmailById(String id);
  Future<void> markAsRead(String id);
  Future<void> markAsUnread(String id);
  Future<void> toggleStar(String id, {required bool currentlyStarred});
  Future<void> deleteEmail(String id);
  Future<void> sendEmail(ComposeEmailModel email);
}

class EmailRepository implements IEmailRepository {
  final GmailService _service;

  EmailRepository(this._service);

  @override
  Future<List<EmailModel>> getEmails({
    String folder = 'Inbox',
    int pageSize = 30,
  }) => _service.getEmails(folder: folder, pageSize: pageSize);

  @override
  Future<EmailModel?> getEmailById(String id) => _service.getEmailById(id);

  @override
  Future<void> markAsRead(String id) => _service.markAsRead(id);

  @override
  Future<void> markAsUnread(String id) => _service.markAsUnread(id);

  @override
  Future<void> toggleStar(String id, {required bool currentlyStarred}) =>
      _service.toggleStar(id, star: !currentlyStarred);

  @override
  Future<void> deleteEmail(String id) => _service.deleteEmail(id);

  @override
  Future<void> sendEmail(ComposeEmailModel email) => _service.sendEmail(email);
}

// ─── Auth repository ──────────────────────────────────────────────────────────

abstract class IAuthRepository {
  Future<EmailConfig> login();
  Future<void> logout();
  Future<EmailConfig?> restoreSession();
}

class AuthRepository implements IAuthRepository {
  final GmailService _gmail;
  final CredentialStorage _storage;

  AuthRepository(this._gmail, this._storage);

  @override
  Future<EmailConfig> login() async {
    final config = await _gmail.signIn();
    await _storage.save(config);
    return config;
  }

  @override
  Future<void> logout() async {
    await _gmail.signOut();
    await _storage.clear();
  }

  @override
  Future<EmailConfig?> restoreSession() async {
    // First try silent Google sign-in (refreshes token automatically)
    final config = await _gmail.restoreSession();
    if (config != null) {
      await _storage.save(config); // update stored display info
      return config;
    }
    return null;
  }
}
