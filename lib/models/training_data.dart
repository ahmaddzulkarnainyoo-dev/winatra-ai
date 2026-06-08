import 'package:hive/hive.dart';

part 'training_data.g.dart';

@HiveType(typeId: 0)
class TrainingData extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String filename;

  @HiveField(2)
  late String content;

  @HiveField(3)
  late DateTime uploadedAt;

  TrainingData({
    required this.id,
    required this.filename,
    required this.content,
    required this.uploadedAt,
  });
}
