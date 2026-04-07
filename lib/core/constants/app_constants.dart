class AppConstants {
  // App Info
  static const String appName = 'Mailflow';
  static const String appVersion = '1.0.0';

  // Animation Durations
  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 350);
  static const Duration longAnim = Duration(milliseconds: 600);

  // UI
  static const double borderRadius = 16.0;
  static const double cardRadius = 12.0;
  static const double pagePadding = 20.0;
  static const double avatarRadius = 22.0;
}

class AppRoutes {
  static const String login = '/login';
  static const String inbox = '/inbox';
  static const String emailDetail = '/email/:id';
  static const String compose = '/compose';
}

class MailFolder {
  static const String inbox = 'Inbox';
  static const String sent = 'Sent';
  static const String drafts = 'Drafts';
  static const String starred = 'Starred';
  static const String trash = 'Trash';
  static const String spam = 'Spam';
}
