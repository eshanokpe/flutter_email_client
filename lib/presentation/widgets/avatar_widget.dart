import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SenderAvatar extends StatelessWidget {
  final String name;
  final String colorHex;
  final bool isRead;
  final double radius;

  const SenderAvatar({
    super.key,
    required this.name,
    required this.colorHex,
    this.isRead = true,
    this.radius = 22,
  });

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return AppTheme.highlight;
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(colorHex);
    final initials = _getInitials(name);

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: color.withOpacity(0.85),
          child: Text(
            initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.6,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (!isRead)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.unreadDot,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
