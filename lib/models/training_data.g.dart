// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrainingDataAdapter extends TypeAdapter<TrainingData> {
  @override
  final int typeId = 0;

  @override
  TrainingData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrainingData(
      id: fields[0] as String,
      filename: fields[1] as String,
      content: fields[2] as String,
      uploadedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TrainingData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.filename)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.uploadedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
