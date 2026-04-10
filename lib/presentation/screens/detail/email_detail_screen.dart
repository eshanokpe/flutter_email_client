import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/email_providers.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/email_body_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/email_model.dart';

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
  bool _headerExpanded = false;

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
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.gmailBlue),
        ),
      );
    }

    if (_error != null || _email == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurfaceMuted),
          onPressed: () => context.pop(),
        ),
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.archive_outlined,
              color: AppTheme.onSurfaceMuted,
            ),
            tooltip: 'Archive',
            onPressed: () {
              ref.read(emailListProvider.notifier).deleteEmail(email.id);
              context.pop();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.onSurfaceMuted,
            ),
            tooltip: 'Delete',
            onPressed: () {
              ref.read(emailListProvider.notifier).deleteEmail(email.id);
              context.pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Moved to Trash')));
            },
          ),
          IconButton(
            icon: Icon(
              email.isRead
                  ? Icons.mark_email_unread_outlined
                  : Icons.done_all_rounded,
              color: AppTheme.onSurfaceMuted,
            ),
            onPressed: () {
              if (email.isRead) {
                ref.read(emailListProvider.notifier).markAsUnread(email.id);
              } else {
                ref.read(emailListProvider.notifier).markAsRead(email.id);
              }
              setState(() => _email = email.copyWith(isRead: !email.isRead));
            },
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: AppTheme.onSurfaceMuted),
            onSelected: (v) {
              if (v == 'reply') {
                context.push(
                  AppRoutes.compose,
                  extra: {
                    'replyTo': email.senderEmail,
                    'subject': 'Re: ${email.subject}',
                  },
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reply', child: Text('Reply')),
              PopupMenuItem(value: 'forward', child: Text('Forward')),
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subject
          Text(
            email.subject,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurface,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          // Sender header
          _buildSenderHeader(email),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          // Body — HTML rendered in WebView, plain text as SelectableText
          EmailBodyView(
            body: email.body.isNotEmpty ? email.body : email.preview,
            isHtml: email.isHtml,
          ),
          const SizedBox(height: 40),
          // Reply / Forward buttons
          _buildReplyBar(context, email),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSenderHeader(EmailModel email) {
    return GestureDetector(
      onTap: () => setState(() => _headerExpanded = !_headerExpanded),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SenderAvatar(
            name: email.senderName,
            email: email.senderEmail,
            photoUrl:
                null, // You'll need to fetch sender photos separately via People API
            colorHex: email.senderAvatarColor,
            radius: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email.senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, y, h:mm a').format(email.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
                if (!_headerExpanded)
                  Text(
                    'to me',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  )
                else ...[
                  Text(
                    'from: ${email.senderEmail}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    'to: ${email.recipientEmail}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    'date: ${DateFormat('EEEE, MMMM d, y, h:mm a').format(email.timestamp)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    'subject: ${email.subject}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
                Icon(
                  _headerExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTheme.onSurfaceMuted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              email.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: email.isStarred
                  ? AppTheme.starColor
                  : AppTheme.onSurfaceMuted,
              size: 22,
            ),
            onPressed: () {
              ref.read(emailListProvider.notifier).toggleStar(email.id);
              setState(
                () => _email = email.copyWith(isStarred: !email.isStarred),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.reply_outlined,
              color: AppTheme.onSurfaceMuted,
              size: 22,
            ),
            onPressed: () => context.push(
              AppRoutes.compose,
              extra: {
                'replyTo': email.senderEmail,
                'subject': 'Re: ${email.subject}',
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar(BuildContext context, EmailModel email) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(
              AppRoutes.compose,
              extra: {
                'replyTo': email.senderEmail,
                'subject': 'Re: ${email.subject}',
              },
            ),
            icon: const Icon(Icons.reply_outlined, size: 18),
            label: const Text('Reply'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.onSurfaceMuted,
              side: const BorderSide(color: AppTheme.divider),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.compose),
            icon: const Icon(Icons.forward_outlined, size: 18),
            label: const Text('Forward'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.onSurfaceMuted,
              side: const BorderSide(color: AppTheme.divider),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
