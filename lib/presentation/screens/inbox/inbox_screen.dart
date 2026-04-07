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
  final _searchController = TextEditingController();
  bool _isSearching = false;

  final List<Map<String, dynamic>> _folders = [
    {'name': MailFolder.inbox, 'icon': Icons.inbox_rounded},
    {'name': MailFolder.sent, 'icon': Icons.send_rounded},
    {'name': MailFolder.starred, 'icon': Icons.star_rounded},
    {'name': MailFolder.drafts, 'icon': Icons.drafts_rounded},
    {'name': MailFolder.trash, 'icon': Icons.delete_outline_rounded},
    {'name': MailFolder.spam, 'icon': Icons.report_gmailerrorred_rounded},
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

  void _openDrawer(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final emailState = ref.watch(emailListProvider);
    final selectedFolder = ref.watch(selectedFolderProvider);

    return Scaffold(
      drawer: _buildDrawer(context, selectedFolder),
      body: RefreshIndicator(
        color: AppTheme.highlight,
        backgroundColor: AppTheme.surface,
        onRefresh: () async {
          final folder = ref.read(selectedFolderProvider);
          await ref
              .read(emailListProvider.notifier)
              .loadEmails(folder, refresh: true);
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, emailState, selectedFolder),
            if (_isSearching)
              SliverToBoxAdapter(child: _buildSearchBar())
            else
              SliverToBoxAdapter(child: _buildFolderChips(selectedFolder)),
            if (emailState.isLoading)
              const SliverFillRemaining(child: _LoadingShimmer())
            else if (emailState.error != null)
              SliverFillRemaining(
                child: _ErrorState(
                  error: emailState.error!,
                  onRetry: () {
                    ref
                        .read(emailListProvider.notifier)
                        .loadEmails(selectedFolder);
                  },
                ),
              )
            else if (emailState.filteredEmails.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final email = emailState.filteredEmails[index];
                  return _EmailTile(
                    email: email,
                    index: index,
                    onTap: () async {
                      await ref
                          .read(emailListProvider.notifier)
                          .markAsRead(email.id);
                      if (context.mounted) {
                        context.push('/email/${email.id}');
                      }
                    },
                    onDelete: () => ref
                        .read(emailListProvider.notifier)
                        .deleteEmail(email.id),
                    onToggleStar: () => ref
                        .read(emailListProvider.notifier)
                        .toggleStar(email.id),
                    onToggleRead: () {
                      if (email.isRead) {
                        ref
                            .read(emailListProvider.notifier)
                            .markAsUnread(email.id);
                      } else {
                        ref
                            .read(emailListProvider.notifier)
                            .markAsRead(email.id);
                      }
                    },
                  );
                }, childCount: emailState.filteredEmails.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    EmailListState emailState,
    String selectedFolder,
  ) {
    final unread = emailState.emails.where((e) => !e.isRead).length;
    final config = ref.watch(activeConfigProvider);
    final initial =
        (config?.displayName.isNotEmpty == true
                ? config!.displayName[0]
                : config?.email[0] ?? 'M')
            .toUpperCase();

    return SliverAppBar(
      floating: true,
      snap: true,
      leading: Builder(
        builder: (ctx) => IconButton(
          onPressed: () => _openDrawer(ctx),
          icon: const Icon(Icons.menu_rounded),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selectedFolder, style: Theme.of(context).textTheme.titleLarge),
          if (unread > 0)
            Text(
              '$unread unread',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.highlight,
                fontSize: 11,
              ),
            ),
        ],
      ),
      actions: [
        if (emailState.isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.highlight,
              ),
            ),
          ),
        IconButton(
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                ref.read(emailListProvider.notifier).setSearchQuery('');
              }
            });
          },
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _showProfileMenu(context, config),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppTheme.highlight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (q) =>
            ref.read(emailListProvider.notifier).setSearchQuery(q),
        decoration: InputDecoration(
          hintText: 'Search emails...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(emailListProvider.notifier).setSearchQuery('');
                  },
                )
              : null,
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3);
  }

  Widget _buildFolderChips(String selected) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _folders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final folder = _folders[i];
          final isSelected = folder['name'] == selected;
          return GestureDetector(
            onTap: () {
              ref.read(selectedFolderProvider.notifier).state = folder['name'];
              ref.read(emailListProvider.notifier).loadEmails(folder['name']);
            },
            child: AnimatedContainer(
              duration: AppConstants.shortAnim,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.highlight : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.highlight : AppTheme.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    folder['icon'] as IconData,
                    size: 14,
                    color: isSelected ? Colors.white : AppTheme.onSurfaceMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    folder['name'] as String,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String selectedFolder) {
    final config = ref.watch(activeConfigProvider);
    final name = config?.displayName ?? 'Mailflow User';
    final email = config?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';

    return Drawer(
      backgroundColor: AppTheme.secondary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.highlight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.mail_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
              child: Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(email, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _folders.map((folder) {
                  final isSelected = folder['name'] == selectedFolder;
                  return ListTile(
                    leading: Icon(
                      folder['icon'] as IconData,
                      color: isSelected
                          ? AppTheme.highlight
                          : AppTheme.onSurfaceMuted,
                      size: 22,
                    ),
                    title: Text(
                      folder['name'] as String,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isSelected
                            ? AppTheme.highlight
                            : AppTheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppTheme.highlight.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      ref.read(selectedFolderProvider.notifier).state =
                          folder['name'];
                      ref
                          .read(emailListProvider.notifier)
                          .loadEmails(folder['name']);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: AppTheme.onSurfaceMuted,
              ),
              title: Text(
                'Sign out',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
                context.go(AppRoutes.login);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => context.push(AppRoutes.compose),
      backgroundColor: AppTheme.highlight,
      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
      label: const Text(
        'Compose',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ).animate().scale(
      delay: 400.ms,
      duration: 300.ms,
      curve: Curves.elasticOut,
    );
  }

  void _showProfileMenu(BuildContext context, EmailConfig? config) {
    final name = config?.displayName ?? 'You';
    final email = config?.email ?? '';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : email[0].toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.highlight,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(email, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(authProvider.notifier).logout();
                  context.go(AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surface,
                ),
                child: const Text(
                  'Sign out',
                  style: TextStyle(color: AppTheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  final EmailModel email;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleStar;
  final VoidCallback onToggleRead;

  const _EmailTile({
    required this.email,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStar,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => onToggleRead(),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                icon: email.isRead
                    ? Icons.mark_email_unread_outlined
                    : Icons.done_all_rounded,
                label: email.isRead ? 'Unread' : 'Read',
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              SlidableAction(
                onPressed: (_) => onDelete(),
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
              ),
            ],
          ),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => onToggleStar(),
                backgroundColor: AppTheme.warningAmber,
                foregroundColor: Colors.white,
                icon: email.isStarred ? Icons.star : Icons.star_outline_rounded,
                label: email.isStarred ? 'Unstar' : 'Star',
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              color: email.isRead ? AppTheme.primary : AppTheme.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SenderAvatar(
                          name: email.senderName,
                          colorHex: email.senderAvatarColor,
                          isRead: email.isRead,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      email.senderName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: email.isRead
                                                ? FontWeight.w400
                                                : FontWeight.w600,
                                            color: email.isRead
                                                ? AppTheme.onSurfaceMuted
                                                : AppTheme.onSurface,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (email.isStarred)
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: AppTheme.warningAmber,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeago.format(
                                      email.timestamp,
                                      allowFromNow: true,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 11,
                                          color: email.isRead
                                              ? AppTheme.onSurfaceMuted
                                              : AppTheme.unreadDot,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      email.subject,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: email.isRead
                                                ? FontWeight.w400
                                                : FontWeight.w600,
                                            fontSize: 13,
                                            color: email.isRead
                                                ? AppTheme.onSurfaceMuted
                                                : AppTheme.onSurface,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (email.hasAttachment) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.attach_file_rounded,
                                      size: 13,
                                      color: AppTheme.onSurfaceMuted,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email.preview,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 72),
                ],
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.05, curve: Curves.easeOut);
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) =>
          Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _shimmerBox(44, 44, radius: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _shimmerBox(120, 12, radius: 4),
                              const Spacer(),
                              _shimmerBox(40, 10, radius: 4),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _shimmerBox(double.infinity, 12, radius: 4),
                          const SizedBox(height: 6),
                          _shimmerBox(200, 10, radius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: AppTheme.surfaceVariant),
    );
  }

  Widget _shimmerBox(double w, double h, {required double radius}) {
    return Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: AppTheme.onSurfaceMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox_rounded,
            size: 64,
            color: AppTheme.onSurfaceMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'No emails in this folder',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
