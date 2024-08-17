// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forum.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ForumAdapter extends TypeAdapter<Forum> {
  @override
  final int typeId = 10;

  @override
  Forum read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Forum(
      id: fields[0] as int,
      fgroup: fields[1] as int,
      sort: fields[2] as int,
      name: fields[3] as String,
      showName: fields[4] as String,
      msg: fields[5] as String,
      interval: fields[6] as int,
      safeMode: fields[7] as int,
      autoDelete: fields[8] as int,
      threadCount: fields[9] as int,
      permissionLevel: fields[10] as int,
      forumFuseId: fields[11] as int,
      createdAt: fields[12] as String,
      updatedAt: fields[13] as String,
      status: fields[14] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Forum obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fgroup)
      ..writeByte(2)
      ..write(obj.sort)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.showName)
      ..writeByte(5)
      ..write(obj.msg)
      ..writeByte(6)
      ..write(obj.interval)
      ..writeByte(7)
      ..write(obj.safeMode)
      ..writeByte(8)
      ..write(obj.autoDelete)
      ..writeByte(9)
      ..write(obj.threadCount)
      ..writeByte(10)
      ..write(obj.permissionLevel)
      ..writeByte(11)
      ..write(obj.forumFuseId)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ForumListAdapter extends TypeAdapter<ForumList> {
  @override
  final int typeId = 11;

  @override
  ForumList read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ForumList(
      id: fields[0] as int,
      sort: fields[1] as int,
      name: fields[2] as String,
      status: fields[3] as String,
      forums: (fields[4] as List).cast<Forum>(),
    );
  }

  @override
  void write(BinaryWriter writer, ForumList obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sort)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.forums);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumListAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
