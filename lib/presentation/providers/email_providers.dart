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

// ========== MULTI-ACCOUNT PROVIDERS - ADD THESE HERE ==========
// Provider for managing multiple accounts
final accountsProvider = StateProvider<List<EmailConfig>>((ref) => []);

// Provider for the currently selected account
final currentAccountProvider = StateProvider<EmailConfig?>((ref) => null);

// Update activeConfigProvider to be derived from currentAccount
final activeConfigProvider = Provider<EmailConfig?>((ref) {
  final currentAccount = ref.watch(currentAccountProvider);
  final accounts = ref.watch(accountsProvider);

  if (currentAccount != null) return currentAccount;
  if (accounts.isNotEmpty) return accounts.first;
  return null;
});

final emailRepositoryProvider = Provider<EmailRepository?>((ref) {
  final config = ref.watch(activeConfigProvider);
  if (config == null) return null;
  return EmailRepository(ref.watch(gmailServiceProvider));
});
// ========== END MULTI-ACCOUNT PROVIDERS ==========

// ─── Auth state ───────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final bool isRestoringSession;
  final String? error;
  final EmailConfig? config;
  final List<EmailConfig> accounts;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.isRestoringSession = false,
    this.error,
    this.config,
    this.accounts = const [],
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    bool? isRestoringSession,
    String? error,
    EmailConfig? config,
    List<EmailConfig>? accounts,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      error: error,
      config: config ?? this.config,
      accounts: accounts ?? this.accounts,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _loadAccounts(); // Change this from _tryRestoreSession to _loadAccounts
  }

  // Add this method - LOAD ACCOUNTS ON STARTUP
  Future<void> _loadAccounts() async {
    state = state.copyWith(isRestoringSession: true);
    try {
      final savedAccounts = await _repo.getSavedAccounts();

      if (savedAccounts.isNotEmpty) {
        // Update accounts provider
        _ref.read(accountsProvider.notifier).state = savedAccounts;

        // Get last active account or use first
        final lastAccount = await _repo.getLastActiveAccount();
        final activeAccount = lastAccount ?? savedAccounts.first;

        // Update current account provider
        _ref.read(currentAccountProvider.notifier).state = activeAccount;

        state = state.copyWith(
          isLoggedIn: true,
          isRestoringSession: false,
          config: activeAccount,
          accounts: savedAccounts,
        );
        return;
      }
    } catch (e) {
      print('Error loading accounts: $e');
    }
    state = state.copyWith(isRestoringSession: false);
  }

  // Add this method - ADD NEW ACCOUNT
  // Add this method - ADD NEW ACCOUNT (forces account picker)
  Future<bool> addAccount() async {
    print('➕ Adding new account');
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Use the new method that forces account picker
      final config = await _repo.addNewAccount();
      print('✅ New account added: ${config.email}');

      // Check if account already exists
      final currentAccounts = _ref.read(accountsProvider);
      final existingIndex = currentAccounts.indexWhere(
        (a) => a.email == config.email,
      );

      List<EmailConfig> updatedAccounts;
      if (existingIndex >= 0) {
        // Update existing account
        updatedAccounts = [...currentAccounts];
        updatedAccounts[existingIndex] = config;
        print('📝 Updated existing account');
      } else {
        // Add new account
        updatedAccounts = [...currentAccounts, config];
        print('➕ Added new account to list');
      }

      _ref.read(accountsProvider.notifier).state = updatedAccounts;

      // Save all accounts
      await _repo.saveAccounts(updatedAccounts);

      // Switch to the new account
      _ref.read(currentAccountProvider.notifier).state = config;
      await _repo.saveLastActiveAccount(config);

      // Force refresh email repository
      _ref.invalidate(emailRepositoryProvider);

      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        config: config,
        accounts: updatedAccounts,
      );

      // Load emails for the new account
      _ref.read(emailListProvider.notifier).loadEmails(MailFolder.inbox);

      return true;
    } on GmailException catch (e) {
      print('❌ Add account GmailException: ${e.message}');
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      print('❌ Add account error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add account. Please try again.',
      );
      return false;
    }
  }

  // Add this method - SWITCH ACCOUNT
  Future<void> switchAccount(EmailConfig config) async {
    print('🔄 Switching to account: ${config.email}');
    _ref.read(currentAccountProvider.notifier).state = config;
    await _repo.saveLastActiveAccount(config);
    _ref.invalidate(emailRepositoryProvider);

    state = state.copyWith(config: config, isLoggedIn: true);

    // Reload emails for the new account
    _ref.read(emailListProvider.notifier).loadEmails(MailFolder.inbox);
  }

  // Add this method - REMOVE ACCOUNT
  Future<void> removeAccount(EmailConfig config) async {
    print('🗑️ Removing account: ${config.email}');
    final currentAccounts = _ref.read(accountsProvider);
    final updatedAccounts = currentAccounts
        .where((a) => a.email != config.email)
        .toList();

    _ref.read(accountsProvider.notifier).state = updatedAccounts;
    await _repo.saveAccounts(updatedAccounts);
    await _repo.removeAccount(config);

    if (updatedAccounts.isEmpty) {
      // No accounts left, sign out completely
      await logout();
    } else if (_ref.read(currentAccountProvider)?.email == config.email) {
      // Switch to first available account
      final nextAccount = updatedAccounts.first;
      _ref.read(currentAccountProvider.notifier).state = nextAccount;
      await _repo.saveLastActiveAccount(nextAccount);
      _ref.invalidate(emailRepositoryProvider);
      state = state.copyWith(config: nextAccount, accounts: updatedAccounts);
      _ref.read(emailListProvider.notifier).loadEmails(MailFolder.inbox);
    } else {
      state = state.copyWith(accounts: updatedAccounts);
    }
  }

  // Update login to add account instead of replacing
  Future<bool> login() async {
    return addAccount();
  }

  Future<void> logout() async {
    print('🔐 Logout from all accounts');
    await _repo.logout();
    _ref.read(accountsProvider.notifier).state = [];
    _ref.read(currentAccountProvider.notifier).state = null;
    _ref.invalidate(emailRepositoryProvider);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

// ─── Selected folder ──────────────────────────────────────────────────────────

final selectedFolderProvider = StateProvider<String>((_) => MailFolder.inbox);

// ─── Email category ───────────────────────────────────────────────────────────

enum EmailCategory { primary, social, promotions, updates, forums }

// ─── Email list state ─────────────────────────────────────────────────────────

class EmailListState {
  final List<EmailModel> emails;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final bool isRefreshing;
  final bool isLoadingPhotos;
  final EmailCategory selectedCategory;

  const EmailListState({
    this.emails = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.isRefreshing = false,
    this.isLoadingPhotos = false,
    this.selectedCategory = EmailCategory.primary,
  });

  EmailListState copyWith({
    List<EmailModel>? emails,
    bool? isLoading,
    String? error,
    String? searchQuery,
    bool? isRefreshing,
    bool? isLoadingPhotos,
    EmailCategory? selectedCategory,
  }) {
    return EmailListState(
      emails: emails ?? this.emails,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingPhotos: isLoadingPhotos ?? this.isLoadingPhotos,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  List<EmailModel> get filteredEmails {
    List<EmailModel> result = emails;

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((e) {
        return e.senderName.toLowerCase().contains(q) ||
            e.senderEmail.toLowerCase().contains(q) ||
            e.subject.toLowerCase().contains(q) ||
            e.preview.toLowerCase().contains(q);
      }).toList();
    }

    if (selectedCategory != EmailCategory.primary) {
      result = result
          .where((e) => _matchesCategory(e, selectedCategory))
          .toList();
    }

    return result;
  }

  bool _matchesCategory(EmailModel email, EmailCategory category) {
    final senderLower = email.senderEmail.toLowerCase();
    final subjectLower = email.subject.toLowerCase();
    final previewLower = email.preview.toLowerCase();

    switch (category) {
      case EmailCategory.social:
        return [
          'facebook',
          'twitter',
          'instagram',
          'linkedin',
          'social',
          'fb',
        ].any((k) => senderLower.contains(k) || subjectLower.contains(k));
      case EmailCategory.promotions:
        return [
          'deal',
          'offer',
          'sale',
          'discount',
          'promotion',
          'coupon',
          'save',
        ].any((k) => subjectLower.contains(k) || previewLower.contains(k));
      case EmailCategory.updates:
        return [
          'update',
          'notification',
          'alert',
          'reminder',
          'confirm',
          'receipt',
        ].any((k) => subjectLower.contains(k));
      case EmailCategory.forums:
        return [
          'forum',
          'discussion',
          'thread',
          'reply',
          'comment',
        ].any((k) => senderLower.contains(k) || subjectLower.contains(k));
      default:
        return true;
    }
  }
}

class EmailListNotifier extends StateNotifier<EmailListState> {
  final Ref _ref;
  bool _photoLoadActive = false;

  EmailListNotifier(this._ref) : super(const EmailListState());

  EmailRepository? get _repo => _ref.read(emailRepositoryProvider);
  GmailService get _gmail => _ref.read(gmailServiceProvider);

  Future<void> loadEmails(String folder, {bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isRefreshing: true, error: null);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final repo = _repo;
      if (repo == null)
        throw Exception('Not authenticated. Please sign in again.');

      final emails = await repo.getEmails(folder: folder);
      state = state.copyWith(
        emails: emails,
        isLoading: false,
        isRefreshing: false,
        selectedCategory: EmailCategory.primary,
      );

      if (emails.isNotEmpty && !_photoLoadActive) {
        _loadPhotosInBackground(emails);
      }
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

  Future<void> _loadPhotosInBackground(List<EmailModel> emails) async {
    _photoLoadActive = true;
    state = state.copyWith(isLoadingPhotos: true);

    final seen = <String>{};
    final uniqueSenders = emails
        .where((e) => e.senderPhotoUrl == null && seen.add(e.senderEmail))
        .toList();

    for (final email in uniqueSenders) {
      if (!mounted) break;
      try {
        final photoUrl = await _gmail.fetchSenderPhoto(email.senderEmail);
        if (photoUrl != null && photoUrl.isNotEmpty && mounted) {
          final updatedEmails = state.emails.map((e) {
            return e.senderEmail == email.senderEmail
                ? e.copyWith(senderPhotoUrl: photoUrl)
                : e;
          }).toList();
          state = state.copyWith(emails: updatedEmails);
        }
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (_) {}
    }

    _photoLoadActive = false;
    state = state.copyWith(isLoadingPhotos: false);
  }

  void setCategory(EmailCategory? category) {
    print('📁 Setting category to: $category');
    state = state.copyWith(selectedCategory: category ?? EmailCategory.primary);
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
