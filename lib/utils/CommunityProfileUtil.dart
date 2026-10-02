/// 社区响应中的头像信息；author 是服务端已应用匿名策略的资料。
class CommunityProfileUtil {
  static const int defaultAvatarId = 1;

  static int avatarIdFromJson(Map<String, dynamic> json) {
    final author = json['author'];
    // author 存在时不回退到旧字段，避免用旧头像绕过服务端匿名遮罩。
    final value = json.containsKey('author')
        ? (author is Map ? author['avatarId'] : null)
        : json['avatarId'];
    return normalizeAvatarId(value);
  }

  static int normalizeAvatarId(Object? value) {
    final int? id;
    if (value is int) {
      id = value;
    } else if (value is num &&
        value.isFinite &&
        value == value.roundToDouble()) {
      id = value.toInt();
    } else if (value is String) {
      id = int.tryParse(value);
    } else {
      id = null;
    }
    return id != null && id > 0 && id <= 4294967295 ? id : defaultAvatarId;
  }
}
