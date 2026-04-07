import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/email_model.dart';
import '../../data/models/email_config.dart';
import '../../data/repositories/email_repository.dart';
import '../../data/services/gmail_service.dart';
import '../../data/services/credential_storage.dart';
import '../../core/constants/app_constants.dart';

// ─── Infrastructure ───────────────────────────────────────────────────────────

final gmailServiceProvider = Provider<GmailService>((_) => GmailService());

final credentialStorageProvider = Provider<CredentialStorage>(
  (_) => CredentialStorage(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(gmailServiceProvider),
    ref.watch(credentialStorageProvider),
  );
});

final activeConfigProvider = StateProvider<EmailConfig?>((ref) => null);

final emailRepositoryProvider = Provider<EmailRepository?>((ref) {
  final config = ref.watch(activeConfigProvider);
  if (config == null) return null;
  return EmailRepository(ref.watch(gmailServiceProvider));
});

// ─── Auth state ───────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final bool isRestoringSession;
  final String? error;
  final EmailConfig? config;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.isRestoringSession = false,
    this.error,
    this.config,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    bool? isRestoringSession,
    String? error,
    EmailConfig? config,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      error: error,
      config: config ?? this.config,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    state = state.copyWith(isRestoringSession: true);
    try {
      final config = await _repo.restoreSession();
      if (config != null) {
        _ref.read(activeConfigProvider.notifier).state = config;
        state = state.copyWith(
          isLoggedIn: true,
          isRestoringSession: false,
          config: config,
        );
        return;
      }
    } catch (_) {}
    state = state.copyWith(isRestoringSession: false);
  }

  Future<bool> login() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final config = await _repo.login();
      _ref.read(activeConfigProvider.notifier).state = config;
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        config: config,
      );
      return true;
    } on GmailException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign-in failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _ref.read(activeConfigProvider.notifier).state = null;
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

// ─── Selected folder ──────────────────────────────────────────────────────────

final selectedFolderProvider = StateProvider<String>((_) => MailFolder.inbox);

// ─── Email list state ─────────────────────────────────────────────────────────

class EmailListState {
  final List<EmailModel> emails;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final bool isRefreshing;

  const EmailListState({
    this.emails = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.isRefreshing = false,
  });

  EmailListState copyWith({
    List<EmailModel>? emails,
    bool? isLoading,
    String? error,
    String? searchQuery,
    bool? isRefreshing,
  }) {
    return EmailListState(
      emails: emails ?? this.emails,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  List<EmailModel> get filteredEmails {
    if (searchQuery.isEmpty) return emails;
    final q = searchQuery.toLowerCase();
    return emails.where((e) {
      return e.senderName.toLowerCase().contains(q) ||
          e.senderEmail.toLowerCase().contains(q) ||
          e.subject.toLowerCase().contains(q) ||
          e.preview.toLowerCase().contains(q);
    }).toList();
  }
}

class EmailListNotifier extends StateNotifier<EmailListState> {
  final Ref _ref;

  EmailListNotifier(this._ref) : super(const EmailListState());

  EmailRepository? get _repo => _ref.read(emailRepositoryProvider);

  Future<void> loadEmails(String folder, {bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isRefreshing: true, error: null);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final repo = _repo;
      if (repo == null) throw Exception('Not authenticated');
      final emails = await repo.getEmails(folder: folder);
      state = state.copyWith(
        emails: emails,
        isLoading: false,
        isRefreshing: false,
      );
    } on GmailException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  Future<void> markAsRead(String id) async {
    _updateLocal(id, (e) => e.copyWith(isRead: true));
    try {
      await _repo?.markAsRead(id);
    } catch (_) {
      _updateLocal(id, (e) => e.copyWith(isRead: false));
    }
  }

  Future<void> markAsUnread(String id) async {
    _updateLocal(id, (e) => e.copyWith(isRead: false));
    try {
      await _repo?.markAsUnread(id);
    } catch (_) {
      _updateLocal(id, (e) => e.copyWith(isRead: true));
    }
  }

  Future<void> toggleStar(String id) async {
    final email = state.emails.firstWhere((e) => e.id == id);
    final wasStarred = email.isStarred;
    _updateLocal(id, (e) => e.copyWith(isStarred: !wasStarred));
    try {
      await _repo?.toggleStar(id, currentlyStarred: wasStarred);
    } catch (_) {
      _updateLocal(id, (e) => e.copyWith(isStarred: wasStarred));
    }
  }

  Future<void> deleteEmail(String id) async {
    final removed = state.emails.firstWhere((e) => e.id == id);
    state = state.copyWith(
      emails: state.emails.where((e) => e.id != id).toList(),
    );
    try {
      await _repo?.deleteEmail(id);
    } catch (_) {
      state = state.copyWith(emails: [...state.emails, removed]);
    }
  }

  void _updateLocal(String id, EmailModel Function(EmailModel) fn) {
    state = state.copyWith(
      emails: state.emails.map((e) => e.id == id ? fn(e) : e).toList(),
    );
  }
}

final emailListProvider =
    StateNotifierProvider<EmailListNotifier, EmailListState>(
      (ref) => EmailListNotifier(ref),
    );

// ─── Compose state ────────────────────────────────────────────────────────────

class ComposeState {
  final bool isSending;
  final bool isSent;
  final String? error;

  const ComposeState({this.isSending = false, this.isSent = false, this.error});

  ComposeState copyWith({bool? isSending, bool? isSent, String? error}) =>
      ComposeState(
        isSending: isSending ?? this.isSending,
        isSent: isSent ?? this.isSent,
        error: error,
      );
}

class ComposeNotifier extends StateNotifier<ComposeState> {
  final Ref _ref;

  ComposeNotifier(this._ref) : super(const ComposeState());

  Future<bool> sendEmail(ComposeEmailModel email) async {
    if (email.to.isEmpty || !email.to.contains('@')) {
      state = state.copyWith(
        error: 'Please enter a valid recipient email address',
      );
      return false;
    }
    if (email.subject.isEmpty) {
      state = state.copyWith(error: 'Please add a subject line');
      return false;
    }
    state = state.copyWith(isSending: true, error: null);
    try {
      final repo = _ref.read(emailRepositoryProvider);
      if (repo == null) throw Exception('Not authenticated');
      await repo.sendEmail(email);
      state = state.copyWith(isSending: false, isSent: true);
      return true;
    } on GmailException catch (e) {
      state = state.copyWith(isSending: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Failed to send. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const ComposeState();
}

final composeProvider = StateNotifierProvider<ComposeNotifier, ComposeState>(
  (ref) => ComposeNotifier(ref),
);
