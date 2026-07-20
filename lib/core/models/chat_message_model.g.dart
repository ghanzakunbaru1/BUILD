// GENERATED CODE - manually written to match build_runner output.
// Run `flutter pub run build_runner build --delete-conflicting-outputs`
// any time you change chat_message_model.dart to regenerate this safely.

part of 'chat_message_model.dart';

class ChatMessageModelAdapter extends TypeAdapter<ChatMessageModel> {
  @override
  final int typeId = 0;

  @override
  ChatMessageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessageModel(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      content: fields[2] as String,
      role: fields[3] as MessageRole,
      timestamp: fields[4] as DateTime,
      attachmentType: fields[5] as AttachmentType,
      attachmentPath: fields[6] as String?,
      isError: fields[7] as bool,
      isStreaming: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.attachmentType)
      ..writeByte(6)
      ..write(obj.attachmentPath)
      ..writeByte(7)
      ..write(obj.isError)
      ..writeByte(8)
      ..write(obj.isStreaming);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageRoleAdapter extends TypeAdapter<MessageRole> {
  @override
  final int typeId = 1;

  @override
  MessageRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageRole.user;
      case 1:
        return MessageRole.ai;
      case 2:
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }

  @override
  void write(BinaryWriter writer, MessageRole obj) {
    switch (obj) {
      case MessageRole.user:
        writer.writeByte(0);
        break;
      case MessageRole.ai:
        writer.writeByte(1);
        break;
      case MessageRole.system:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttachmentTypeAdapter extends TypeAdapter<AttachmentType> {
  @override
  final int typeId = 2;

  @override
  AttachmentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttachmentType.none;
      case 1:
        return AttachmentType.image;
      case 2:
        return AttachmentType.audio;
      case 3:
        return AttachmentType.pdf;
      case 4:
        return AttachmentType.docx;
      case 5:
        return AttachmentType.txt;
      case 6:
        return AttachmentType.zip;
      case 7:
        return AttachmentType.csv;
      case 8:
        return AttachmentType.json;
      case 9:
        return AttachmentType.other;
      default:
        return AttachmentType.none;
    }
  }

  @override
  void write(BinaryWriter writer, AttachmentType obj) {
    switch (obj) {
      case AttachmentType.none:
        writer.writeByte(0);
        break;
      case AttachmentType.image:
        writer.writeByte(1);
        break;
      case AttachmentType.audio:
        writer.writeByte(2);
        break;
      case AttachmentType.pdf:
        writer.writeByte(3);
        break;
      case AttachmentType.docx:
        writer.writeByte(4);
        break;
      case AttachmentType.txt:
        writer.writeByte(5);
        break;
      case AttachmentType.zip:
        writer.writeByte(6);
        break;
      case AttachmentType.csv:
        writer.writeByte(7);
        break;
      case AttachmentType.json:
        writer.writeByte(8);
        break;
      case AttachmentType.other:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
