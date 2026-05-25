import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';

class LuoXuePlayer {
  final String name; // 游戏内名称
  final int rating; // 玩家 DXRating
  final int friendCode; // 好友码
  final int courseRank; // 段位id
  final int classRank; // 阶级id
  final int star; // 搭档觉醒数
  final Collection? trophy; // 仅上传时可空，称号
  final Collection? icon; // 值可空，头像
  final Collection? namePlate; // 值可空，姓名框
  final Collection? frame; // 值可空，背景
  final String? uploadTime; // 仅获取玩家信息返回，玩家被同步时的 UTC 时间

  LuoXuePlayer({
    required this.name,
    required this.rating,
    required this.friendCode,
    required this.courseRank,
    required this.classRank,
    required this.star,
    this.trophy,
    this.icon,
    this.namePlate,
    this.frame,
    this.uploadTime,
  });

  factory LuoXuePlayer.fromJson(Map<String, dynamic> json) {
    return LuoXuePlayer(
      name: json['name'] ?? '',
      rating: json['rating'] ?? 0,
      friendCode: json['friend_code'] ?? 0,
      courseRank: json['course_rank'] ?? 0,
      classRank: json['class_rank'] ?? 0,
      star: json['star'] ?? 0,
      trophy: json['trophy'] != null ? Collection.fromJson(json['trophy']) : null,
      icon: json['icon'] != null ? Collection.fromJson(json['icon']) : null,
      namePlate: json['name_plate'] != null ? Collection.fromJson(json['name_plate']) : null,
      frame: json['frame'] != null ? Collection.fromJson(json['frame']) : null,
      uploadTime: json['upload_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rating': rating,
      'friend_code': friendCode,
      'course_rank': courseRank,
      'class_rank': classRank,
      'star': star,
      'trophy': trophy?.toJson(),
      'icon': icon?.toJson(),
      'name_plate': namePlate?.toJson(),
      'frame': frame?.toJson(),
      'upload_time': uploadTime,
    };
  }

  @override
  String toString() {
    return 'LuoXuePlayer{name: $name, rating: $rating, friendCode: $friendCode}';
  }
}