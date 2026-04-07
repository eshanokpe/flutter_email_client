import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/email_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/email_model.dart';
import '../../widgets/avatar_widget.dart';

class EmailDetailScreen extends ConsumerStatefulWidget {
  final String emailId;

  const EmailDetailScreen({super.key, required this.emailId});

  @override
  ConsumerState<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends ConsumerState<EmailDetailScreen> {
  EmailModel? _email;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final repo = ref.read(emailRepositoryProvider);
      if (repo == null) throw Exception('Not authenticated');
      final email = await repo.getEmailById(widget.emailId);
      if (mounted) {
        setState(() {
          _email = email;
          _isLoading = false;
        });
        if (email != null && !email.isRead) {
          ref.read(emailListProvider.notifier).markAsRead(email.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.highlight,
          ),
        ),
      );
    }

    if (_error != null || _email == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.onSurfaceMuted,
              ),
              const SizedBox(height: 16),
              Text(_error ?? 'Email not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final email = _email!;
    final formattedDate = DateFormat(
      'EEEE, MMMM d, y · h:mm a',
    ).format(email.timestamp);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  final isRead = email.isRead;
                  if (isRead) {
                    ref.read(emailListProvider.notifier).markAsUnread(email.id);
                  } else {
                    ref.read(emailListProvider.notifier).markAsRead(email.id);
                  }
                  setState(() {
                    _email = email.copyWith(isRead: !isRead);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        email.isRead ? 'Marked as unread' : 'Marked as read',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: email.isRead ? 'Mark as unread' : 'Mark as read',
                icon: Icon(
                  email.isRead
                      ? Icons.mark_email_unread_outlined
                      : Icons.done_all_rounded,
                  color: AppTheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(emailListProvider.notifier).toggleStar(email.id);
                  setState(() {
                    _email = email.copyWith(isStarred: !email.isStarred);
                  });
                },
                icon: Icon(
                  email.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: email.isStarred
                      ? AppTheme.warningAmber
                      : AppTheme.onSurface,
                ),
              ),
              PopupMenuButton<String>(
                color: AppTheme.surface,
                onSelected: (value) {
                  if (value == 'delete') {
                    ref.read(emailListProvider.notifier).deleteEmail(email.id);
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email moved to trash')),
                    );
                  } else if (value == 'reply') {
                    context.push(
                      AppRoutes.compose,
                      extra: {
                        'replyTo': email.senderEmail,
                        'subject': 'Re: ${email.subject}',
                      },
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reply',
                    child: Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Reply'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'forward',
                    child: Row(
                      children: [
                        Icon(Icons.forward_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Forward'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppTheme.errorRed,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppTheme.errorRed),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject
                  Text(
                    email.subject,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 20,
                      height: 1.3,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  // Tags
                  if (email.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: email.tags
                          .map((tag) => _buildTag(context, tag))
                          .toList(),
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                  const SizedBox(height: 20),
                  // Sender row
                  _buildSenderInfo(
                    context,
                    email,
                    formattedDate,
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  // Body
                  _buildEmailBody(
                    context,
                    email,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 40),
                  // Reply bar
                  _buildReplyBar(
                    context,
                    email,
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderInfo(
    BuildContext context,
    EmailModel email,
    String formattedDate,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SenderAvatar(name: email.senderName, colorHex: email.senderAvatarColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email.senderName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                email.senderEmail,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                'To: ${email.recipientEmail}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: AppTheme.onSurfaceMuted.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        if (email.hasAttachment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  size: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '1 file',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmailBody(BuildContext context, EmailModel email) {
    return SelectableText(
      email.body,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(height: 1.7, color: AppTheme.onSurface),
    );
  }

  Widget _buildReplyBar(BuildContext context, EmailModel email) {
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.compose,
        extra: {
          'replyTo': email.senderEmail,
          'subject': 'Re: ${email.subject}',
        },
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.reply_rounded,
              size: 18,
              color: AppTheme.onSurfaceMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reply to ${email.senderName}...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.send_rounded, size: 16, color: AppTheme.highlight),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String tag) {
    final tagColors = {
      'urgent': AppTheme.errorRed,
      'work': AppTheme.unreadDot,
      'important': AppTheme.warningAmber,
      'finance': AppTheme.successGreen,
      'design': AppTheme.highlight,
      'code': const Color(0xFF9C27B0),
      'opportunity': AppTheme.successGreen,
    };
    final color = tagColors[tag] ?? AppTheme.onSurfaceMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
