import 'package:flutter/material.dart';
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
  late final TextEditingController _toCtrl;
  late final TextEditingController _subjectCtrl;
  final TextEditingController _bodyCtrl = TextEditingController();
  bool _showCc = false;
  final TextEditingController _ccCtrl = TextEditingController();
  final TextEditingController _bccCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.initialTo ?? '');
    _subjectCtrl = TextEditingController(text: widget.initialSubject ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(composeProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _ccCtrl.dispose();
    _bccCtrl.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _toCtrl.text.isNotEmpty ||
      _subjectCtrl.text.isNotEmpty ||
      _bodyCtrl.text.isNotEmpty;

  Future<void> _handleSend() async {
    final email = ComposeEmailModel(
      to: _toCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
    );
    final ok = await ref.read(composeProvider.notifier).sendEmail(email);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent')));
      context.pop();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasContent) return true;
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Save draft'),
              onTap: () => Navigator.pop(context, 'draft'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.gmailRed,
              ),
              title: const Text(
                'Discard draft',
                style: TextStyle(color: AppTheme.gmailRed),
              ),
              onTap: () => Navigator.pop(context, 'discard'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result == 'draft') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved')));
    }
    return result != null;
  }

  @override
  Widget build(BuildContext context) {
    final composeState = ref.watch(composeProvider);
    final config = ref.watch(activeConfigProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        // Gmail compose uses a custom top bar — not a standard AppBar
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.onSurfaceMuted,
                      ),
                      onPressed: () async {
                        if (await _onWillPop()) context.pop();
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'New message',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                    // Send button
                    IconButton(
                      icon: composeState.isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.gmailBlue,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: AppTheme.gmailBlue,
                            ),
                      onPressed: composeState.isSending ? null : _handleSend,
                    ),
                  ],
                ),
              ),

              if (composeState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFFFCE8E6),
                  child: Text(
                    composeState.error!,
                    style: const TextStyle(
                      color: AppTheme.gmailRed,
                      fontSize: 13,
                    ),
                  ),
                ),

              const Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // From
                      _buildFieldRow(
                        label: 'From',
                        child: Text(
                          config?.email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),

                      // To
                      _buildFieldRow(
                        label: 'To',
                        child: TextField(
                          controller: _toCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () => setState(() => _showCc = !_showCc),
                          child: Text(
                            _showCc ? '' : 'Cc/Bcc',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),

                      if (_showCc) ...[
                        _buildFieldRow(
                          label: 'Cc',
                          child: TextField(
                            controller: _ccCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                        _buildFieldRow(
                          label: 'Bcc',
                          child: TextField(
                            controller: _bccCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                      ],

                      // Subject
                      _buildFieldRow(
                        label: 'Subject',
                        child: TextField(
                          controller: _subjectCtrl,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),

                      // Body
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: TextField(
                          controller: _bodyCtrl,
                          maxLines: null,
                          minLines: 16,
                          decoration: const InputDecoration(
                            hintText: 'Compose email',
                            hintStyle: TextStyle(
                              color: AppTheme.onSurfaceMuted,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom formatting bar
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.divider, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file_outlined,
                        color: AppTheme.onSurfaceMuted,
                        size: 22,
                      ),
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Attachment coming soon'),
                            ),
                          ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.link_outlined,
                        color: AppTheme.onSurfaceMuted,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: AppTheme.onSurfaceMuted,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppTheme.onSurfaceMuted,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
