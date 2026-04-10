import 'package:equatable/equatable.dart';

// In email_model.dart - add photoUrl field
class EmailModel extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String senderAvatarColor;
  final String? senderPhotoUrl; // Add this field
  final String recipientEmail;
  final String subject;
  final String body;
  final bool isHtml;
  final String preview;
  final DateTime timestamp;
  final bool isRead;
  final bool isStarred;
  final bool hasAttachment;
  final String folder;
  final List<String> tags;

  const EmailModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.senderAvatarColor,
    this.senderPhotoUrl, // Add this
    required this.recipientEmail,
    required this.subject,
    required this.body,
    this.isHtml = false,
    required this.preview,
    required this.timestamp,
    this.isRead = false,
    this.isStarred = false,
    this.hasAttachment = false,
    this.folder = 'Inbox',
    this.tags = const [],
  });

  // Update copyWith
  EmailModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderEmail,
    String? senderAvatarColor,
    String? senderPhotoUrl,
    String? recipientEmail,
    String? subject,
    String? body,
    bool? isHtml,
    String? preview,
    DateTime? timestamp,
    bool? isRead,
    bool? isStarred,
    bool? hasAttachment,
    String? folder,
    List<String>? tags,
  }) {
    return EmailModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      senderAvatarColor: senderAvatarColor ?? this.senderAvatarColor,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      isHtml: isHtml ?? this.isHtml,
      preview: preview ?? this.preview,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    senderEmail,
    senderAvatarColor,
    senderPhotoUrl,
    recipientEmail,
    subject,
    body,
    isHtml,
    preview,
    timestamp,
    isRead,
    isStarred,
    hasAttachment,
    folder,
    tags,
  ];
}

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
  });

  @override
  List<Object?> get props => [id, name, email];
}

class ComposeEmailModel {
  final String to;
  final String subject;
  final String body;

  const ComposeEmailModel({
    required this.to,
    required this.subject,
    required this.body,
  });
}
