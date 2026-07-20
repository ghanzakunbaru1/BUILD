import 'package:hive/hive.dart';

part 'chat_message_model.g.dart';

/// Who sent the message.
@HiveType(typeId: 1)
enum MessageRole {
  @HiveField(0)
  user,
  @HiveField(1)
  ai,
  @HiveField(2)
  system,
}

/// The kind of attachment (if any) carried by a message.
@HiveType(typeId: 2)
enum AttachmentType {
  @HiveField(0)
  none,
  @HiveField(1)
  image,
  @HiveField(2)
  audio,
  @HiveField(3)
  pdf,
  @HiveField(4)
  docx,
  @HiveField(5)
  txt,
  @HiveField(6)
  zip,
  @HiveField(7)
  csv,
  @HiveField(8)
  json,
  @HiveField(9)
  other,
}

@HiveType(typeId: 0)
class ChatMessageModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  String content;

  @HiveField(3)
  final MessageRole role;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final AttachmentType attachmentType;

  /// Local file path of the attachment, if any.
  @HiveField(6)
  final String? attachmentPath;

  @HiveField(7)
  bool isError;

  @HiveField(8)
  bool isStreaming;

  ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.role,
    required this.timestamp,
    this.attachmentType = AttachmentType.none,
    this.attachmentPath,
    this.isError = false,
    this.isStreaming = false,
  });
}
