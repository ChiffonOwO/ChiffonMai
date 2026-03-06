/// 歌曲别名接口数据模型
class SongAliasResponse {
  final int code;
  final List<SongAliasItem> content;

  SongAliasResponse({required this.code, required this.content});

  // 从JSON解析成模型
  factory SongAliasResponse.fromJson(Map<String, dynamic> json) {
    var contentList = json['content'] as List;
    List<SongAliasItem> songs = contentList
        .map((item) => SongAliasItem.fromJson(item))
        .toList();

    return SongAliasResponse(
      code: json['code'] as int,
      content: songs,
    );
  }
}

class SongAliasItem {
  final String name;
  final bool isVotable;
  final int songId;
  final List<String> alias;

  SongAliasItem({
    required this.name,
    required this.isVotable,
    required this.songId,
    required this.alias,
  });

  factory SongAliasItem.fromJson(Map<String, dynamic> json) {
    var aliasList = json['Alias'] as List;
    List<String> aliases = aliasList.map((a) => a as String).toList();

    return SongAliasItem(
      name: json['Name'] as String,
      isVotable: json['IsVotable'] as bool,
      songId: json['SongID'] as int,
      alias: aliases,
    );
  }
}