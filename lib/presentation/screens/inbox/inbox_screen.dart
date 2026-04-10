import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/email_providers.dart';
import '../../widgets/avatar_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/email_model.dart';
import '../../../data/models/email_config.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  final _folders = [
    {
      'name': MailFolder.inbox,
      'icon': Icons.inbox_outlined,
      'activeIcon': Icons.inbox,
      'label': 'Inbox',
    },
    {
      'name': MailFolder.starred,
      'icon': Icons.star_outline_rounded,
      'activeIcon': Icons.star_rounded,
      'label': 'Starred',
    },
    {
      'name': MailFolder.sent,
      'icon': Icons.send_outlined,
      'activeIcon': Icons.send,
      'label': 'Sent',
    },
    {
      'name': MailFolder.drafts,
      'icon': Icons.drafts_outlined,
      'activeIcon': Icons.drafts,
      'label': 'Drafts',
    },
    {
      'name': MailFolder.trash,
      'icon': Icons.delete_outline_rounded,
      'activeIcon': Icons.delete_rounded,
      'label': 'Trash',
    },
    {
      'name': MailFolder.spam,
      'icon': Icons.report_outlined,
      'activeIcon': Icons.report,
      'label': 'Spam',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emailListProvider.notifier).loadEmails(MailFolder.inbox);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailState = ref.watch(emailListProvider);
    final selectedFolder = ref.watch(selectedFolderProvider);
    final config = ref.watch(activeConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildDrawer(context, selectedFolder, config),
      body: Column(
        children: [
          _buildSearchBar(context, config, emailState),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.gmailBlue,
              onRefresh: () => ref
                  .read(emailListProvider.notifier)
                  .loadEmails(selectedFolder, refresh: true),
              child: _buildEmailList(emailState, selectedFolder),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    EmailConfig? config,
    EmailListState emailState,
  ) {
    final initial =
        (config?.displayName.isNotEmpty == true ? config!.displayName[0] : 'G')
            .toUpperCase();

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        color: Colors.white,
        child: GestureDetector(
          onTap: () => setState(() => _isSearching = !_isSearching),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF5F6368),
                      size: 24,
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isSearching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search in mail',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintStyle: TextStyle(
                              color: Color(0xFF5F6368),
                              fontSize: 16,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF202124),
                          ),
                          onChanged: (q) => ref
                              .read(emailListProvider.notifier)
                              .setSearchQuery(q),
                        )
                      : const Text(
                          'Search in mail',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                ),
                if (_isSearching)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF5F6368),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _isSearching = false);
                      _searchController.clear();
                      ref.read(emailListProvider.notifier).setSearchQuery('');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else ...[
                  if (emailState.isRefreshing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.gmailBlue,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _showAccountSheet(context, config),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _avatarBg(config?.email ?? ''),
                        shape: BoxShape.circle,
                      ),
                      child:
                          (config?.photoUrl != null &&
                              config!.photoUrl!.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                config.photoUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailList(EmailListState emailState, String folder) {
    if (emailState.isLoading) return _buildShimmer();
    if (emailState.error != null) {
      return _buildError(emailState.error!, folder);
    }
    if (emailState.filteredEmails.isEmpty) return _buildEmpty(folder);

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: emailState.filteredEmails.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, thickness: 0.5, color: Color(0xFFE8EAED)),
      itemBuilder: (context, i) {
        final email = emailState.filteredEmails[i];
        return _GmailEmailTile(
          email: email,
          index: i,
          onTap: () async {
            await ref.read(emailListProvider.notifier).markAsRead(email.id);
            if (context.mounted) context.push('/email/${email.id}');
          },
          onStar: () =>
              ref.read(emailListProvider.notifier).toggleStar(email.id),
          onDelete: () =>
              ref.read(emailListProvider.notifier).deleteEmail(email.id),
          onMarkUnread: () =>
              ref.read(emailListProvider.notifier).markAsUnread(email.id),
        );
      },
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    String selected,
    EmailConfig? config,
  ) {
    final initial =
        (config?.displayName.isNotEmpty == true ? config!.displayName[0] : 'G')
            .toUpperCase();

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  const Text(
                    'Gmail',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFC5221F),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EAED)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _folders.map((f) {
                  final isSelected = f['name'] == selected;
                  return _DrawerItem(
                    icon: isSelected
                        ? f['activeIcon'] as IconData
                        : f['icon'] as IconData,
                    label: f['label'] as String,
                    selected: isSelected,
                    onTap: () {
                      ref.read(selectedFolderProvider.notifier).state =
                          f['name'] as String;
                      ref
                          .read(emailListProvider.notifier)
                          .loadEmails(f['name'] as String);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EAED)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _avatarBg(config?.email ?? ''),
                      shape: BoxShape.circle,
                    ),
                    child:
                        (config?.photoUrl != null &&
                            config!.photoUrl!.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              config.photoUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config?.displayName ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF202124),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          config?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F6368),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout_outlined,
                      size: 20,
                      color: Color(0xFF5F6368),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(authProvider.notifier).logout();
                      context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.compose),
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
        ),
        icon: const Icon(
          Icons.edit_outlined,
          color: Color(0xFFC5221F),
          size: 20,
        ),
        label: const Text(
          'Compose',
          style: TextStyle(
            color: Color(0xFF3C4043),
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.25,
          ),
        ),
      ),
    );
  }

  void _showAccountSheet(BuildContext context, EmailConfig? config) {
    final initial =
        (config?.displayName.isNotEmpty == true ? config!.displayName[0] : 'G')
            .toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDADCE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Google Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDADCE0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: _avatarBg(config?.email ?? ''),
                  backgroundImage:
                      (config?.photoUrl != null && config!.photoUrl!.isNotEmpty)
                      ? NetworkImage(config.photoUrl!)
                      : null,
                  child: (config?.photoUrl == null || config!.photoUrl!.isEmpty)
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  config?.displayName ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFF202124),
                  ),
                ),
                subtitle: Text(
                  config?.email ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5F6368),
                  ),
                ),
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppTheme.gmailBlue,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.add,
                color: AppTheme.gmailBlue,
                size: 22,
              ),
              title: const Text(
                'Add another account',
                style: TextStyle(fontSize: 14, color: AppTheme.gmailBlue),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).login();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_outlined,
                color: Color(0xFF5F6368),
                size: 22,
              ),
              title: const Text(
                'Sign out',
                style: TextStyle(fontSize: 14, color: Color(0xFF3C4043)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
                context.go(AppRoutes.login);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Color _avatarBg(String email) {
    const colors = [
      Color(0xFFD93025),
      Color(0xFF1A73E8),
      Color(0xFF34A853),
      Color(0xFFF9AB00),
      Color(0xFFE37400),
      Color(0xFF9334E6),
    ];
    if (email.isEmpty) return colors[1];
    return colors[email.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  Widget _buildShimmer() {
    return ListView.separated(
      itemCount: 10,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, thickness: 0.5, color: Color(0xFFE8EAED)),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFE8EAED),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 140,
                    color: const Color(0xFFE8EAED),
                  ),
                  const SizedBox(height: 6),
                  Container(height: 13, color: const Color(0xFFE8EAED)),
                  const SizedBox(height: 4),
                  Container(
                    height: 12,
                    width: 220,
                    color: const Color(0xFFE8EAED),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error, String folder) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 56,
            color: Color(0xFF5F6368),
          ),
          const SizedBox(height: 16),
          const Text(
            'Can\'t load emails',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Color(0xFF5F6368), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () =>
                ref.read(emailListProvider.notifier).loadEmails(folder),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDADCE0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String folder) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: const Color(0xFF9AA0A6)),
          const SizedBox(height: 16),
          Text(
            folder == MailFolder.inbox ? 'No new email' : 'No messages here',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Color(0xFF5F6368),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F0FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.gmailBlue : const Color(0xFF5F6368),
              ),
              const SizedBox(width: 32),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppTheme.gmailBlue
                      : const Color(0xFF202124),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GmailEmailTile extends StatelessWidget {
  final EmailModel email;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onDelete;
  final VoidCallback onMarkUnread;

  const _GmailEmailTile({
    required this.email,
    required this.index,
    required this.onTap,
    required this.onStar,
    required this.onDelete,
    required this.onMarkUnread,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !email.isRead;

    return Slidable(
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.3,
            children: [
              SlidableAction(
                onPressed: (_) => onMarkUnread(),
                backgroundColor: AppTheme.gmailBlue,
                foregroundColor: Colors.white,
                icon: Icons.mark_email_unread_outlined,
                label: 'Unread',
                borderRadius: BorderRadius.circular(0),
              ),
              SlidableAction(
                onPressed: (_) => onDelete(),
                backgroundColor: const Color(0xFFEA4335),
                foregroundColor: Colors.white,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                borderRadius: BorderRadius.circular(0),
              ),
            ],
          ),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.15,
            children: [
              SlidableAction(
                onPressed: (_) => onStar(),
                backgroundColor: const Color(0xFFFBBC04),
                foregroundColor: Colors.white,
                icon: email.isStarred ? Icons.star : Icons.star_outline_rounded,
                label: '',
                borderRadius: BorderRadius.circular(0),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: Container(
              color: isUnread ? const Color(0xFFF8F9FA) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SenderAvatar(
                    name: email.senderName,
                    email: email.senderEmail,
                    photoUrl: email.senderPhotoUrl,
                    colorHex: email.senderAvatarColor,
                    radius: 18,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                email.senderName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: const Color(0xFF202124),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (email.isStarred)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: const Color(0xFFFBBC04),
                                ),
                              ),
                            Text(
                              timeago.format(
                                email.timestamp,
                                allowFromNow: true,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                email.subject,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: const Color(0xFF202124),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (email.hasAttachment) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.attach_file,
                                size: 14,
                                color: Color(0xFF5F6368),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email.preview,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5F6368),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 30))
        .fadeIn(duration: 200.ms);
  }
}
