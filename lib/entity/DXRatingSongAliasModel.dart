class DXRatingSongAliasModel {
  final List<DXRatingSongAliasEntity> data;

  DXRatingSongAliasModel(this.data);

  factory DXRatingSongAliasModel.fromJson(List<dynamic> json) {
    List<DXRatingSongAliasEntity> items = json
        .map((item) => DXRatingSongAliasEntity.fromJson(item))
        .toList();
    return DXRatingSongAliasModel(items);
  }
}

class DXRatingSongAliasEntity {
  final String songId; // 歌名
  final String name; // 别名

  DXRatingSongAliasEntity({
    required this.songId,
    required this.name,
  });

  factory DXRatingSongAliasEntity.fromJson(Map<String, dynamic> json) {
    return DXRatingSongAliasEntity(
      songId: json['song_id'] as String,
      name: json['name'] as String,
    );
  }
}