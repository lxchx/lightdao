// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_filter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ForumThreadFilterAdapter extends TypeAdapter<ForumThreadFilter> {
  @override
  final int typeId = 12;

  @override
  ForumThreadFilter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ForumThreadFilter(fid: fields[0] as int);
  }

  @override
  void write(BinaryWriter writer, ForumThreadFilter obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.fid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumThreadFilterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IdThreadFilterAdapter extends TypeAdapter<IdThreadFilter> {
  @override
  final int typeId = 13;

  @override
  IdThreadFilter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdThreadFilter(id: fields[0] as int);
  }

  @override
  void write(BinaryWriter writer, IdThreadFilter obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdThreadFilterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserHashFilterAdapter extends TypeAdapter<UserHashFilter> {
  @override
  final int typeId = 14;

  @override
  UserHashFilter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserHashFilter(userHash: fields[0] as String);
  }

  @override
  void write(BinaryWriter writer, UserHashFilter obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.userHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserHashFilterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
