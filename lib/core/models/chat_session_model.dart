import 'package:hive/hive.dart';

part 'chat_session_model.g.dart';

@HiveType(typeId: 3)
class ChatSessionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  ChatSessionModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
}
