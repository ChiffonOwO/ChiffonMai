import 'RecordItem.dart';

class UserPlayDataEntity {
  final int additionalRating;
  final String nickname;
  final String plate;
  final int rating;
  final List<RecordItem> records;

  UserPlayDataEntity(
      {required this.additionalRating,
      required this.nickname,
      required this.plate,
      required this.rating,
      required this.records
      });
  
  // 从JSON根对象解析为UserPlayDataEntity实例
  factory UserPlayDataEntity.fromJson(Map<String, dynamic> json) {
    // 解析嵌套的records数组：List<dynamic> → List<RecordItem>
    List<RecordItem> recordList = [];
    if (json['records'] is List) {
      recordList = (json['records'] as List)
          .map((item) => RecordItem.fromJson(item ?? {})) // 单个item解析为RecordItem
          .toList();
    }

    return UserPlayDataEntity(
      additionalRating: json['additional_rating'] ?? 0, // 兜底默认值
      nickname: json['nickname'] ?? '',
      plate: json['plate'] ?? '',
      rating: json['rating'] ?? 0,
      records: recordList,
    );
  }
}
