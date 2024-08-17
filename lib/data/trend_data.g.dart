// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trend_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrendDataAdapter extends TypeAdapter<TrendData> {
  @override
  final int typeId = 15;

  @override
  TrendData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrendData(
      fetchTime: fields[0] as DateTime,
      reply: fields[1] as ReplyJson,
    );
  }

  @override
  void write(BinaryWriter writer, TrendData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.fetchTime)
      ..writeByte(1)
      ..write(obj.reply);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
