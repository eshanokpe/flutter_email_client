import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Auth method — only Gmail OAuth for now, easy to extend later.
enum AuthMethod { gmailOAuth }

/// Lightweight session model stored in secure storage after sign-in.
class EmailConfig extends Equatable {
  final String displayName;
  final String email;
  final String photoUrl;
  final AuthMethod authMethod;

  const EmailConfig({
    required this.displayName,
    required this.email,
    this.photoUrl = '',
    this.authMethod = AuthMethod.gmailOAuth,
  });

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'authMethod': authMethod.name,
  };

  String toJsonString() => jsonEncode(toJson());

  factory EmailConfig.fromJson(Map<String, dynamic> json) => EmailConfig(
    displayName: json['displayName'] as String,
    email: json['email'] as String,
    photoUrl: (json['photoUrl'] as String?) ?? '',
    authMethod: AuthMethod.values.firstWhere(
      (m) => m.name == json['authMethod'],
      orElse: () => AuthMethod.gmailOAuth,
    ),
  );

  factory EmailConfig.fromJsonString(String s) =>
      EmailConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  List<Object?> get props => [email, authMethod];
}
