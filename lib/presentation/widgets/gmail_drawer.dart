// lib/presentation/widgets/gmail_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter_email_client/presentation/providers/email_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/email_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/email_config.dart';

class GmailDrawer extends ConsumerWidget {
  final String selectedFolder;
  final EmailConfig? config;

  const GmailDrawer({
    super.key,
    required this.selectedFolder,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailState = ref.watch(emailListProvider);

    // Get unread counts for different categories
    final inboxUnread = emailState.emails
        .where((e) => !e.isRead && e.folder == MailFolder.inbox)
        .length;

    final socialUnread = emailState.emails
        .where((e) => !e.isRead && _isSocialCategory(e))
        .length;

    final promotionsUnread = emailState.emails
        .where((e) => !e.isRead && _isPromotionsCategory(e))
        .length;

    final updatesUnread = emailState.emails
        .where((e) => !e.isRead && _isUpdatesCategory(e))
        .length;

    final forumsUnread = emailState.emails
        .where((e) => !e.isRead && _isForumsCategory(e))
        .length;

    final starredUnread = emailState.emails
        .where((e) => !e.isRead && e.isStarred)
        .length;

    final sentUnread = emailState.emails
        .where((e) => !e.isRead && e.folder == MailFolder.sent)
        .length;

    final draftsCount = emailState.emails
        .where((e) => e.folder == MailFolder.drafts)
        .length;

    final initial =
        (config?.displayName.isNotEmpty == true ? config!.displayName[0] : 'G')
            .toUpperCase();

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          children: [
            // Account Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gmail',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFC5221F),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFF5F6368),
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(authProvider.notifier).login();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showAccountSheet(context, ref, config);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _avatarBg(config?.email ?? ''),
                            shape: BoxShape.circle,
                          ),
                          child:
                              (config?.photoUrl != null &&
                                  config!.photoUrl!.isNotEmpty)
                              ? ClipOval(
                                  child: Image.network(
                                    config!.photoUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
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
                                      fontSize: 18,
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
                                  fontSize: 15,
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
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFF5F6368),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE8EAED)),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Main inbox categories (like real Gmail)
                  _DrawerCategory(
                    title: 'All inboxes',
                    isSelected: selectedFolder == 'all',
                    onTap: () {
                      ref.read(selectedFolderProvider.notifier).state = 'all';
                      ref.read(emailListProvider.notifier).setCategory(null);
                      ref.read(emailListProvider.notifier).loadEmails('all');
                      Navigator.of(context).pop();
                    },
                  ),

                  const SizedBox(height: 4),

                  // Primary Tab
                  _DrawerItemWithCount(
                    icon: Icons.inbox_outlined,
                    activeIcon: Icons.inbox,
                    label: 'Primary',
                    count: inboxUnread,
                    isSelected:
                        selectedFolder == MailFolder.inbox &&
                        emailState.selectedCategory == null,
                    onTap: () {
                      _selectCategory(ref, context, null);
                    },
                  ),

                  // Social Tab
                  _DrawerItemWithCount(
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: 'Social',
                    count: socialUnread,
                    isSelected:
                        selectedFolder == MailFolder.inbox &&
                        emailState.selectedCategory == EmailCategory.social,
                    onTap: () {
                      _selectCategory(ref, context, EmailCategory.social);
                    },
                  ),

                  // Promotions Tab
                  _DrawerItemWithCount(
                    icon: Icons.local_offer_outlined,
                    activeIcon: Icons.local_offer,
                    label: 'Promotions',
                    count: promotionsUnread,
                    isSelected:
                        selectedFolder == MailFolder.inbox &&
                        emailState.selectedCategory == EmailCategory.promotions,
                    onTap: () {
                      _selectCategory(ref, context, EmailCategory.promotions);
                    },
                  ),

                  // Updates Tab
                  _DrawerItemWithCount(
                    icon: Icons.update_outlined,
                    activeIcon: Icons.update,
                    label: 'Updates',
                    count: updatesUnread,
                    isSelected:
                        selectedFolder == MailFolder.inbox &&
                        emailState.selectedCategory == EmailCategory.updates,
                    onTap: () {
                      _selectCategory(ref, context, EmailCategory.updates);
                    },
                  ),

                  // Forums Tab
                  _DrawerItemWithCount(
                    icon: Icons.forum_outlined,
                    activeIcon: Icons.forum,
                    label: 'Forums',
                    count: forumsUnread,
                    isSelected:
                        selectedFolder == MailFolder.inbox &&
                        emailState.selectedCategory == EmailCategory.forums,
                    onTap: () {
                      _selectCategory(ref, context, EmailCategory.forums);
                    },
                  ),

                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: Color(0xFFE8EAED),
                  ),

                  // Gmail folders
                  _DrawerItemWithCount(
                    icon: Icons.star_outline_rounded,
                    activeIcon: Icons.star_rounded,
                    label: 'Starred',
                    count: starredUnread,
                    isSelected: selectedFolder == MailFolder.starred,
                    onTap: () {
                      _navigateToFolder(ref, context, MailFolder.starred);
                    },
                  ),

                  _DrawerItemWithCount(
                    icon: Icons.send_outlined,
                    activeIcon: Icons.send,
                    label: 'Sent',
                    count: sentUnread,
                    isSelected: selectedFolder == MailFolder.sent,
                    onTap: () {
                      _navigateToFolder(ref, context, MailFolder.sent);
                    },
                  ),

                  _DrawerItemWithCount(
                    icon: Icons.drafts_outlined,
                    activeIcon: Icons.drafts,
                    label: 'Drafts',
                    count: draftsCount,
                    isSelected: selectedFolder == MailFolder.drafts,
                    onTap: () {
                      _navigateToFolder(ref, context, MailFolder.drafts);
                    },
                  ),

                  _DrawerItemWithCount(
                    icon: Icons.delete_outline_rounded,
                    activeIcon: Icons.delete_rounded,
                    label: 'Trash',
                    count: 0,
                    isSelected: selectedFolder == MailFolder.trash,
                    onTap: () {
                      _navigateToFolder(ref, context, MailFolder.trash);
                    },
                  ),

                  _DrawerItemWithCount(
                    icon: Icons.report_outlined,
                    activeIcon: Icons.report,
                    label: 'Spam',
                    count: 0,
                    isSelected: selectedFolder == MailFolder.spam,
                    onTap: () {
                      _navigateToFolder(ref, context, MailFolder.spam);
                    },
                  ),

                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: Color(0xFFE8EAED),
                  ),

                  // Meet section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Meet',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  _DrawerItem(
                    icon: Icons.video_call_outlined,
                    label: 'New meeting',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Open Google Meet
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.schedule_outlined,
                    label: 'Join with code',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Join meeting
                    },
                  ),

                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: Color(0xFFE8EAED),
                  ),

                  // Labels section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Labels',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  _DrawerItem(
                    icon: Icons.label_outline,
                    label: 'Create new label',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Create label
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Bottom Section
            Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE8EAED)),

                // Storage info
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Storage',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: 0.33, // Example: 5GB of 15GB
                        backgroundColor: const Color(0xFFE8EAED),
                        color: AppTheme.gmailBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '5.0 GB of 15 GB used',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE8EAED)),

                // Settings and Help
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Open settings
                  },
                ),

                _DrawerItem(
                  icon: Icons.help_outline,
                  label: 'Help & feedback',
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Open help
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFolder(WidgetRef ref, BuildContext context, String folder) {
    ref.read(selectedFolderProvider.notifier).state = folder;
    // Clear category filter when changing folders
    ref.read(emailListProvider.notifier).setCategory(null);
    ref.read(emailListProvider.notifier).loadEmails(folder);
    Navigator.of(context).pop();
  }

  void _selectCategory(
    WidgetRef ref,
    BuildContext context,
    EmailCategory? category,
  ) {
    // Set the selected folder to inbox (since categories are in inbox)
    ref.read(selectedFolderProvider.notifier).state = MailFolder.inbox;
    // Set the category filter
    ref.read(emailListProvider.notifier).setCategory(category);
    // Load emails to apply filter
    ref.read(emailListProvider.notifier).loadEmails(MailFolder.inbox);
    Navigator.of(context).pop();
  }

  void _showAccountSheet(
    BuildContext context,
    WidgetRef ref,
    EmailConfig? config,
  ) {
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
                  radius: 20,
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
                            fontSize: 16,
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

  bool _isSocialCategory(EmailModel email) {
    final socialKeywords = [
      'facebook',
      'twitter',
      'instagram',
      'linkedin',
      'social',
      'fb',
      'tweet',
    ];
    return socialKeywords.any(
      (keyword) =>
          email.senderEmail.toLowerCase().contains(keyword) ||
          email.senderName.toLowerCase().contains(keyword) ||
          email.subject.toLowerCase().contains(keyword),
    );
  }

  bool _isPromotionsCategory(EmailModel email) {
    final promoKeywords = [
      'deal',
      'offer',
      'sale',
      'discount',
      'promotion',
      'coupon',
      'save',
      'buy',
    ];
    return promoKeywords.any(
      (keyword) =>
          email.subject.toLowerCase().contains(keyword) ||
          email.preview.toLowerCase().contains(keyword),
    );
  }

  bool _isUpdatesCategory(EmailModel email) {
    final updateKeywords = [
      'update',
      'notification',
      'alert',
      'reminder',
      'confirm',
      'receipt',
    ];
    return updateKeywords.any(
      (keyword) => email.subject.toLowerCase().contains(keyword),
    );
  }

  bool _isForumsCategory(EmailModel email) {
    final forumKeywords = [
      'forum',
      'discussion',
      'thread',
      'reply',
      'comment',
      'post',
    ];
    return forumKeywords.any(
      (keyword) =>
          email.senderEmail.toLowerCase().contains(keyword) ||
          email.subject.toLowerCase().contains(keyword),
    );
  }
}

// Drawer Category Header Widget
class _DrawerCategory extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerCategory({
    required this.title,
    required this.isSelected,
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.gmailBlue
                        : const Color(0xFF202124),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF5F6368),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Drawer Item with count badge
class _DrawerItemWithCount extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItemWithCount({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.count,
    required this.isSelected,
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected
                    ? AppTheme.gmailBlue
                    : const Color(0xFF5F6368),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.gmailBlue
                        : const Color(0xFF202124),
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple drawer item without count
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF5F6368)),
              const SizedBox(width: 32),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF202124),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
