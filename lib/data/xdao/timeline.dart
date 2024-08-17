import 'package:hive/hive.dart';

part 'timeline.g.dart';

@HiveType(typeId: 9)
class Timeline extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String displayName;

  @HiveField(3)
  final String notice;

  @HiveField(4)
  final int maxPage;

  Timeline({
    required this.id,
    required this.name,
    required this.displayName,
    required this.notice,
    required this.maxPage,
  });

  String getShowName() {
    return displayName == '' ? name : displayName;
  }

  factory Timeline.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('id') &&
        json.containsKey('name') &&
        json.containsKey('display_name') &&
        json.containsKey('notice') &&
        json.containsKey('max_page')) {
      return Timeline(
        id: json['id'],
        name: json['name'],
        displayName: json['display_name'],
        notice: json['notice'],
        maxPage: json['max_page'],
      );
    } else {
      throw ArgumentError('Invalid JSON format for Timeline');
    }
  }
}
