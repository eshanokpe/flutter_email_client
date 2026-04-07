import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import '../models/email_model.dart';
import '../models/email_config.dart';
import '../../core/constants/app_constants.dart';

const _uuid = Uuid();

// Gmail OAuth scopes needed
const _scopes = [
  gmail.GmailApi.mailGoogleComScope, // full access — read, send, delete, labels
];

final _googleSignIn = GoogleSignIn(scopes: _scopes);

// ─── Auth client that injects Google OAuth headers into every request ─────────
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ─── Folder → Gmail label mapping ────────────────────────────────────────────
String _folderToLabel(String folder) {
  switch (folder) {
    case MailFolder.inbox:
      return 'INBOX';
    case MailFolder.sent:
      return 'SENT';
    case MailFolder.drafts:
      return 'DRAFT';
    case MailFolder.starred:
      return 'STARRED';
    case MailFolder.trash:
      return 'TRASH';
    case MailFolder.spam:
      return 'SPAM';
    default:
      return 'INBOX';
  }
}

String _labelToFolder(List<String>? labels) {
  if (labels == null) return MailFolder.inbox;
  if (labels.contains('SENT')) return MailFolder.sent;
  if (labels.contains('DRAFT')) return MailFolder.drafts;
  if (labels.contains('STARRED')) return MailFolder.starred;
  if (labels.contains('TRASH')) return MailFolder.trash;
  if (labels.contains('SPAM')) return MailFolder.spam;
  return MailFolder.inbox;
}

String _avatarColor(String email) {
  const palette = [
    '#E94560',
    '#4FC3F7',
    '#FFB300',
    '#4CAF50',
    '#9C27B0',
    '#FF7043',
    '#26C6DA',
    '#8D6E63',
  ];
  final code = email.codeUnits.fold(0, (a, b) => a + b);
  return palette[code % palette.length];
}

String _stripHtml(String raw) {
  try {
    return html_parser.parse(raw).body?.text ?? raw;
  } catch (_) {
    return raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }
}

// ─── Main service ─────────────────────────────────────────────────────────────
class GmailService {
  gmail.GmailApi? _api;
  GoogleSignInAccount? _account;

  // ── Sign-in ────────────────────────────────────────────────────────────────

  /// Opens the Google account picker and returns an EmailConfig on success.
  Future<EmailConfig> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw const GmailException('Sign-in cancelled');

      _account = account;
      _api = await _buildApi(account);

      return EmailConfig(
        displayName: account.displayName ?? account.email,
        email: account.email,
        photoUrl: account.photoUrl ?? '',
      );
    } catch (e) {
      if (e is GmailException) rethrow;
      throw GmailException('Sign-in failed: $e');
    }
  }

  /// Silently restores a previous session (no UI shown).
  Future<EmailConfig?> restoreSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;

      _account = account;
      _api = await _buildApi(account);

      return EmailConfig(
        displayName: account.displayName ?? account.email,
        email: account.email,
        photoUrl: account.photoUrl ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _api = null;
    _account = null;
  }

  // ── Fetch emails ───────────────────────────────────────────────────────────

  Future<List<EmailModel>> getEmails({
    String folder = MailFolder.inbox,
    int pageSize = 30,
  }) async {
    final api = _requireApi();
    try {
      final label = _folderToLabel(folder);

      // List message IDs
      final listResponse = await api.users.messages.list(
        'me',
        labelIds: [label],
        maxResults: pageSize,
      );

      final messages = listResponse.messages ?? [];
      if (messages.isEmpty) return [];

      // Fetch each message in parallel (metadata + snippet)
      final futures = messages.map(
        (m) => api.users.messages.get(
          'me',
          m.id!,
          format: 'metadata',
          metadataHeaders: ['From', 'To', 'Subject', 'Date'],
        ),
      );

      final full = await Future.wait(futures);
      return full
          .map((m) => _messageToModel(m, folder))
          .whereType<EmailModel>()
          .toList();
    } catch (e) {
      if (e is GmailException) rethrow;
      throw GmailException('Failed to fetch emails: $e');
    }
  }

  /// Fetch full message body by ID.
  Future<EmailModel?> getEmailById(String id) async {
    final api = _requireApi();
    try {
      // Strip the uuid suffix we appended
      final gmailId = id.contains('-') ? id.split('-').first : id;
      final msg = await api.users.messages.get('me', gmailId, format: 'full');
      return _messageToModel(msg, MailFolder.inbox, fullBody: true);
    } catch (e) {
      throw GmailException('Failed to fetch email: $e');
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> markAsRead(String id) => _modifyLabels(id, remove: ['UNREAD']);
  Future<void> markAsUnread(String id) => _modifyLabels(id, add: ['UNREAD']);

  Future<void> toggleStar(String id, {required bool star}) => star
      ? _modifyLabels(id, add: ['STARRED'])
      : _modifyLabels(id, remove: ['STARRED']);

  Future<void> deleteEmail(String id) async {
    final api = _requireApi();
    try {
      final gmailId = id.contains('-') ? id.split('-').first : id;
      await api.users.messages.trash('me', gmailId);
    } catch (e) {
      throw GmailException('Delete failed: $e');
    }
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> sendEmail(ComposeEmailModel email) async {
    final api = _requireApi();
    final account = _account!;

    try {
      // Build RFC 2822 message
      final rawMessage = _buildRawEmail(
        from: '${account.displayName ?? account.email} <${account.email}>',
        to: email.to,
        subject: email.subject,
        body: email.body,
      );

      await api.users.messages.send(gmail.Message(raw: rawMessage), 'me');
    } catch (e) {
      throw GmailException('Failed to send email: $e');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<gmail.GmailApi> _buildApi(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    final client = _GoogleAuthClient({
      'Authorization': 'Bearer ${auth.accessToken}',
    });
    return gmail.GmailApi(client);
  }

  gmail.GmailApi _requireApi() {
    if (_api == null) throw const GmailException('Not signed in');
    return _api!;
  }

  Future<void> _modifyLabels(
    String id, {
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    final api = _requireApi();
    try {
      final gmailId = id.contains('-') ? id.split('-').first : id;
      await api.users.messages.modify(
        gmail.ModifyMessageRequest(
          addLabelIds: add.isEmpty ? null : add,
          removeLabelIds: remove.isEmpty ? null : remove,
        ),
        'me',
        gmailId,
      );
    } catch (e) {
      throw GmailException('Label update failed: $e');
    }
  }

  EmailModel? _messageToModel(
    gmail.Message msg,
    String folder, {
    bool fullBody = false,
  }) {
    try {
      final headers = msg.payload?.headers ?? [];

      String header(String name) =>
          headers
              .firstWhere(
                (h) => h.name?.toLowerCase() == name.toLowerCase(),
                orElse: () => gmail.MessagePartHeader(value: ''),
              )
              .value ??
          '';

      final from = header('From');
      final subject = header('Subject');
      final dateStr = header('Date');
      final to = header('To');

      // Parse "Display Name <email@domain.com>" or plain email
      final nameMatch = RegExp(r'^(.+?)\s*<(.+?)>$').firstMatch(from);
      final senderName = nameMatch?.group(1)?.trim() ?? from;
      final senderEmail = nameMatch?.group(2)?.trim() ?? from;

      final timestamp = dateStr.isNotEmpty
          ? _parseDate(dateStr)
          : DateTime.now();

      final labels = msg.labelIds ?? [];
      final isRead = !labels.contains('UNREAD');
      final isStarred = labels.contains('STARRED');

      // Body
      String body = '';
      if (fullBody) {
        body = _extractBody(msg.payload) ?? msg.snippet ?? '';
        if (body.contains('<')) body = _stripHtml(body);
      }

      final preview = (msg.snippet ?? '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('\n', ' ')
          .trim();

      final hasAttachment =
          msg.payload?.parts?.any((p) => p.filename?.isNotEmpty == true) ??
          false;

      final id = '${msg.id}-${_uuid.v4().substring(0, 8)}';

      return EmailModel(
        id: id,
        senderId: senderEmail,
        senderName: senderName.isEmpty ? senderEmail : senderName,
        senderEmail: senderEmail,
        senderAvatarColor: _avatarColor(senderEmail),
        recipientEmail: to,
        subject: subject.isEmpty ? '(no subject)' : subject,
        body: fullBody ? body : '',
        preview: preview,
        timestamp: timestamp,
        isRead: isRead,
        isStarred: isStarred,
        hasAttachment: hasAttachment,
        folder: _labelToFolder(labels),
      );
    } catch (_) {
      return null;
    }
  }

  /// Recursively extract the best body part (plain or html).
  String? _extractBody(gmail.MessagePart? part) {
    if (part == null) return null;

    final mime = part.mimeType ?? '';

    // Leaf node with data
    if (part.body?.data != null && part.parts == null) {
      if (mime == 'text/plain' || mime == 'text/html') {
        return _decodeBase64(part.body!.data!);
      }
    }

    // Prefer text/plain in multipart
    if (part.parts != null) {
      final plain = part.parts!
          .where((p) => p.mimeType == 'text/plain')
          .map((p) => p.body?.data)
          .whereType<String>()
          .firstOrNull;
      if (plain != null) return _decodeBase64(plain);

      final html = part.parts!
          .where((p) => p.mimeType == 'text/html')
          .map((p) => p.body?.data)
          .whereType<String>()
          .firstOrNull;
      if (html != null) return _decodeBase64(html);

      // Recurse into nested multipart
      for (final child in part.parts!) {
        final result = _extractBody(child);
        if (result != null) return result;
      }
    }
    return null;
  }

  String _decodeBase64(String data) {
    try {
      // Gmail uses URL-safe base64
      final normalized = data.replaceAll('-', '+').replaceAll('_', '/');
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return data;
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // RFC 2822 dates like "Mon, 01 Jan 2024 12:00:00 +0000"
      try {
        // Try stripping weekday prefix
        final clean = dateStr.replaceFirst(RegExp(r'^\w+,\s*'), '').trim();
        return DateTime.parse(clean);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  /// Build a base64url-encoded RFC 2822 email string.
  String _buildRawEmail({
    required String from,
    required String to,
    required String subject,
    required String body,
  }) {
    final message = [
      'From: $from',
      'To: $to',
      'Subject: $subject',
      'MIME-Version: 1.0',
      'Content-Type: text/plain; charset=utf-8',
      'Content-Transfer-Encoding: quoted-printable',
      '',
      body,
    ].join('\r\n');

    return base64Url.encode(utf8.encode(message));
  }
}

class GmailException implements Exception {
  final String message;
  const GmailException(this.message);

  @override
  String toString() => 'GmailException: $message';
}
