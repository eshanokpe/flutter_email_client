import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis/people/v1.dart' as people;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import '../models/email_model.dart';
import '../models/email_config.dart';
import '../../core/constants/app_constants.dart';

const _uuid = Uuid();

final _scopes = [
  gmail.GmailApi.mailGoogleComScope,
  'https://www.googleapis.com/auth/contacts.readonly',
  'https://www.googleapis.com/auth/userinfo.profile',
];

final _googleSignIn = GoogleSignIn(scopes: _scopes);

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

class GmailService {
  gmail.GmailApi? _api;
  people.PeopleServiceApi? _peopleApi;
  GoogleSignInAccount? _account;
  final Map<String, String?> _photoCache = {};
  final Map<String, Future<String?>> _pendingPhotoFetches = {};

  // ── Sign-in ────────────────────────────────────────────────────────────────

  Future<EmailConfig> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw const GmailException('Sign-in cancelled');
      _account = account;
      await _buildApis(account);
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

  // Add new account with force account picker
  Future<EmailConfig> addNewAccount() async {
    try {
      // Sign out current account to force account picker
      await _googleSignIn.signOut();

      // Sign in again with account picker
      final account = await _googleSignIn.signIn();
      if (account == null) throw const GmailException('Sign-in cancelled');

      _account = account;
      await _buildApis(account);

      return EmailConfig(
        displayName: account.displayName ?? account.email,
        email: account.email,
        photoUrl: account.photoUrl ?? '',
      );
    } catch (e) {
      if (e is GmailException) rethrow;
      throw GmailException('Failed to add account: $e');
    }
  }

  Future<EmailConfig?> restoreSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      _account = account;
      await _buildApis(account);
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
    _peopleApi = null;
    _account = null;
    _photoCache.clear();
    _pendingPhotoFetches.clear();
  }

  // ── Profile photo fetching ─────────────────────────────────────────────────

  Future<String?> fetchSenderPhoto(String email) async {
    if (email.isEmpty) return null;
    if (_photoCache.containsKey(email)) return _photoCache[email];
    if (_pendingPhotoFetches.containsKey(email)) {
      return _pendingPhotoFetches[email];
    }

    final future = _fetchGoogleProfilePhoto(email);
    _pendingPhotoFetches[email] = future;
    try {
      final result = await future;
      _photoCache[email] = result;
      return result;
    } finally {
      _pendingPhotoFetches.remove(email);
    }
  }

  Future<String?> _fetchGoogleProfilePhoto(String email) async {
    if (_peopleApi == null) return null;
    try {
      // Own profile
      if (email == _account?.email) {
        final ownProfile = await _peopleApi!.people.get(
          'people/me',
          personFields: 'photos',
        );
        final url = ownProfile.photos?.firstOrNull?.url;
        if (url != null && url.isNotEmpty) {
          return '${url.split('?').first}?sz=200';
        }
      }

      // Contacts / directory
      final response = await _peopleApi!.people.searchContacts(
        query: email,
        readMask: 'photos,emailAddresses',
        pageSize: 1,
        sources: const [
          'READ_SOURCE_TYPE_CONTACT',
          'READ_SOURCE_TYPE_DIRECTORY',
          'READ_SOURCE_TYPE_DOMAIN_CONTACT',
        ],
      );

      final person = response.results?.firstOrNull?.person;
      if (person != null) {
        final hasMatch =
            person.emailAddresses?.any(
              (e) => e.value?.toLowerCase() == email.toLowerCase(),
            ) ??
            false;
        if (hasMatch) {
          final url = person.photos?.firstOrNull?.url;
          if (url != null && url.isNotEmpty) {
            return '${url.split('?').first}?sz=200';
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Fetch emails ───────────────────────────────────────────────────────────

  Future<List<EmailModel>> getEmails({
    String folder = MailFolder.inbox,
    int pageSize = 30,
  }) async {
    final api = _requireApi();
    try {
      final label = _folderToLabel(folder);
      final listResponse = await api.users.messages.list(
        'me',
        labelIds: [label],
        maxResults: pageSize,
      );

      final messages = listResponse.messages ?? [];
      if (messages.isEmpty) return [];

      final futures = messages.map(
        (m) => api.users.messages.get(
          'me',
          m.id!,
          format: 'metadata',
          metadataHeaders: ['From', 'To', 'Subject', 'Date'],
        ),
      );

      final full = await Future.wait(futures);
      final emails = full
          .map((m) => _messageToModel(m, folder))
          .whereType<EmailModel>()
          .toList();

      // Kick off background photo loading
      _prefetchPhotos(emails);

      return emails;
    } catch (e) {
      if (e is GmailException) rethrow;
      throw GmailException('Failed to fetch emails: $e');
    }
  }

  void _prefetchPhotos(List<EmailModel> emails) {
    final unique = emails.map((e) => e.senderEmail).toSet();
    for (final email in unique) {
      fetchSenderPhoto(email).catchError((_) => null);
    }
  }

  Future<EmailModel?> getEmailById(String id) async {
    final api = _requireApi();
    try {
      final gmailId = id.contains('-') ? id.split('-').first : id;
      final msg = await api.users.messages.get('me', gmailId, format: 'full');
      final email = _messageToModel(msg, MailFolder.inbox, fullBody: true);
      if (email == null) return null;

      final photo = await fetchSenderPhoto(email.senderEmail);
      return photo != null ? email.copyWith(senderPhotoUrl: photo) : email;
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

  Future<void> sendEmail(ComposeEmailModel email) async {
    final api = _requireApi();
    final account = _account!;
    try {
      final raw = _buildRawEmail(
        from: '${account.displayName ?? account.email} <${account.email}>',
        to: email.to,
        subject: email.subject,
        body: email.body,
      );
      await api.users.messages.send(gmail.Message(raw: raw), 'me');
    } catch (e) {
      throw GmailException('Failed to send email: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _buildApis(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    final client = _GoogleAuthClient({
      'Authorization': 'Bearer ${auth.accessToken}',
    });
    _api = gmail.GmailApi(client);
    _peopleApi = people.PeopleServiceApi(client);
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

      final nameMatch = RegExp(r'^(.+?)\s*<(.+?)>$').firstMatch(from);
      final senderName = nameMatch?.group(1)?.trim() ?? from;
      final senderEmail = nameMatch?.group(2)?.trim() ?? from;

      final timestamp = dateStr.isNotEmpty
          ? _parseDate(dateStr)
          : DateTime.now();
      final labels = msg.labelIds ?? [];
      final isRead = !labels.contains('UNREAD');
      final isStarred = labels.contains('STARRED');

      String body = '';
      bool isHtml = false;
      if (fullBody) {
        final htmlBody = _extractBodyByMime(msg.payload, 'text/html');
        if (htmlBody != null) {
          body = htmlBody;
          isHtml = true;
        } else {
          body =
              _extractBodyByMime(msg.payload, 'text/plain') ??
              msg.snippet ??
              '';
        }
      }

      final preview = (msg.snippet ?? '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('\n', ' ')
          .trim();

      final hasAttachment =
          msg.payload?.parts?.any((p) => p.filename?.isNotEmpty == true) ??
          false;

      return EmailModel(
        id: '${msg.id}-${_uuid.v4().substring(0, 8)}',
        senderId: senderEmail,
        senderName: senderName.isEmpty ? senderEmail : senderName,
        senderEmail: senderEmail,
        senderPhotoUrl: _photoCache[senderEmail],
        senderAvatarColor: _avatarColor(senderEmail),
        recipientEmail: to,
        subject: subject.isEmpty ? '(no subject)' : subject,
        body: fullBody ? body : '',
        isHtml: fullBody ? isHtml : false,
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

  String? _extractBodyByMime(gmail.MessagePart? part, String mimeType) {
    if (part == null) return null;
    final mime = part.mimeType ?? '';
    if (part.body?.data != null && part.parts == null) {
      if (mime == mimeType) return _decodeBase64(part.body!.data!);
      return null;
    }
    if (part.parts != null) {
      for (final child in part.parts!) {
        if ((child.mimeType ?? '') == mimeType && child.body?.data != null) {
          return _decodeBase64(child.body!.data!);
        }
      }
      for (final child in part.parts!) {
        final result = _extractBodyByMime(child, mimeType);
        if (result != null) return result;
      }
    }
    return null;
  }

  String _decodeBase64(String data) {
    try {
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
      try {
        final clean = dateStr.replaceFirst(RegExp(r'^\w+,\s*'), '').trim();
        return DateTime.parse(clean);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

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
