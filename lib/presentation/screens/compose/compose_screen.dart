import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/email_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/email_model.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? initialTo;
  final String? initialSubject;

  const ComposeScreen({super.key, this.initialTo, this.initialSubject});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _toController;
  late final TextEditingController _subjectController;
  final TextEditingController _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showCcBcc = false;
  final TextEditingController _ccController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _toController = TextEditingController(text: widget.initialTo ?? '');
    _subjectController = TextEditingController(
      text: widget.initialSubject ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(composeProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_formKey.currentState?.validate() != true) return;

    final email = ComposeEmailModel(
      to: _toController.text.trim(),
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
    );

    final success = await ref.read(composeProvider.notifier).sendEmail(email);
    if (success && mounted) {
      _showSuccessAndPop();
    }
  }

  void _showSuccessAndPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  )
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 600.ms),
              const SizedBox(height: 20),
              Text(
                'Email Sent!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Your message to ${_toController.text} has been delivered.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.pop();
                  },
                  child: const Text('Back to Inbox'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final hasContent =
        _toController.text.isNotEmpty ||
        _subjectController.text.isNotEmpty ||
        _bodyController.text.isNotEmpty;

    if (!hasContent) return true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
            Text(
              'Discard this email?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your draft will not be saved.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Keep editing',
                      style: TextStyle(color: AppTheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final composeState = ref.watch(composeProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _onWillPop()) context.pop();
            },
          ),
          title: const Text('New Message'),
          actions: [
            // Draft button
            TextButton.icon(
              onPressed: composeState.isSending
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Draft saved')),
                      );
                    },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Draft'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(width: 4),
            // Send button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedContainer(
                duration: AppConstants.shortAnim,
                child: ElevatedButton(
                  onPressed: composeState.isSending ? null : _handleSend,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: composeState.isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 14),
                            SizedBox(width: 6),
                            Text('Send'),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              if (composeState.error != null)
                _buildErrorBanner(composeState.error!),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildFromRow(context),
                      _buildDivider(),
                      _buildToRow(context),
                      if (_showCcBcc) ...[
                        _buildDivider(),
                        _buildCcRow(context),
                      ],
                      _buildDivider(),
                      _buildSubjectRow(context),
                      _buildDivider(),
                      _buildBodyField(context),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFromRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            'From',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'demo@mailflow.app',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            'To',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _toController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'Recipients',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                filled: false,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please add a recipient';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showCcBcc = !_showCcBcc),
            child: Text(
              _showCcBcc ? 'Hide' : 'Cc/Bcc',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.highlight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCcRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            'Cc',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _ccController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Cc recipients',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                filled: false,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2);
  }

  Widget _buildSubjectRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: _subjectController,
        decoration: const InputDecoration(
          hintText: 'Subject',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
          filled: false,
        ),
        style: Theme.of(context).textTheme.titleMedium,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please add a subject';
          return null;
        },
      ),
    );
  }

  Widget _buildBodyField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _bodyController,
        maxLines: null,
        minLines: 15,
        decoration: const InputDecoration(
          hintText: 'Write your message...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          filled: false,
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: AppTheme.secondary,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          _iconAction(Icons.attach_file_rounded, 'Attach', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attachment feature coming soon')),
            );
          }),
          const SizedBox(width: 4),
          _iconAction(Icons.image_outlined, 'Image', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image insertion coming soon')),
            );
          }),
          const SizedBox(width: 4),
          _iconAction(Icons.format_bold_rounded, 'Bold', () {}),
          const SizedBox(width: 4),
          _iconAction(Icons.format_italic_rounded, 'Italic', () {}),
          const Spacer(),
          Text(
            '${_bodyController.text.split(' ').where((w) => w.isNotEmpty).length} words',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppTheme.onSurfaceMuted),
        ),
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1);

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.errorRed.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
