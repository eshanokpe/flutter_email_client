import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';

class SenderAvatar extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final String colorHex;
  final double radius;

  const SenderAvatar({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.colorHex,
    this.radius = 18,
  });

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return AppTheme.gmailBlue;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Show real profile photo when available
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl!,
        imageBuilder: (context, imageProvider) =>
            CircleAvatar(radius: radius, backgroundImage: imageProvider),
        placeholder: (context, url) => _initialsAvatar(),
        errorWidget: (context, url, error) => _initialsAvatar(),
        cacheKey: photoUrl,
      );
    }

    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _parseColor(colorHex),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
