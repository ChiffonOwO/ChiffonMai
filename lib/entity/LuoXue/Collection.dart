class CollectionData {
  final List<Collection>? trophies;
  final List<Collection>? icons;
  final List<Collection>? plates;
  final List<Collection>? frames;

  CollectionData({
    this.trophies,
    this.icons,
    this.plates,
    this.frames,
  });

  factory CollectionData.fromJson(Map<String, dynamic> json) {
    return CollectionData(
      trophies: (json['trophies'] as List<dynamic>?)?.map((item) => Collection.fromJson(item)).toList(),
      icons: (json['icons'] as List<dynamic>?)?.map((item) => Collection.fromJson(item)).toList(),
      plates: (json['plates'] as List<dynamic>?)?.map((item) => Collection.fromJson(item)).toList(),
      frames: (json['frames'] as List<dynamic>?)?.map((item) => Collection.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (trophies != null) {
      data['trophies'] = trophies!.map((item) => item.toJson()).toList();
    }
    if (icons != null) {
      data['icons'] = icons!.map((item) => item.toJson()).toList();
    }
    if (plates != null) {
      data['plates'] = plates!.map((item) => item.toJson()).toList();
    }
    if (frames != null) {
      data['frames'] = frames!.map((item) => item.toJson()).toList();
    }
    return data;
  }
}


class Collection {
  final int id;  //收藏品 ID
  final String name;  //收藏品名称
  String? color;  //值可空，仅玩家称号，称号颜色
  String? description;  //值可空，收藏品说明
  String? genre;  //值可空，除玩家称号，收藏品分类（日文）
  List<CollectionRequired>? required;  //值可空，收藏品要求

  Collection({
    required this.id,
    required this.name,
    this.color,
    this.description,
    this.genre,
    this.required,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'],
      description: json['description'],
      genre: json['genre'],
      required: (json['required'] as List<dynamic>?)?.map((item) => CollectionRequired.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
    };
    if (color != null) {
      data['color'] = color;
    }
    if (description != null) {
      data['description'] = description;
    }
    if (genre != null) {
      data['genre'] = genre;
    }
    if (required != null) {
      data['required'] = required!.map((item) => item.toJson()).toList();
    }
    return data;
  }
}

class CollectionRequired {
  List<int>? difficulties;  //值可空，要求的谱面难度，长度为 0 时代表任意难度
  String? rate;  //值可空，要求的评级类型
  String? fc; //值可空，要求的 FULL COMBO 类型
  String? fs; //值可空，要求的 FULL SYNC 类型
  List<CollectionRequiredSong>? songs; //值可空，要求的曲目列表
  bool? completed; //值可空，要求是否全部完成

  CollectionRequired({
    this.difficulties,
    this.rate,
    this.fc,
    this.fs,
    this.songs,
    this.completed,
  });

  factory CollectionRequired.fromJson(Map<String, dynamic> json) {
    return CollectionRequired(
      difficulties: (json['difficulties'] as List<dynamic>?)?.where((item) => item != null).map((item) => item as int).toList(),
      rate: json['rate'],
      fc: json['fc'],
      fs: json['fs'],
      songs: (json['songs'] as List<dynamic>?)?.where((item) => item != null).map((item) => CollectionRequiredSong.fromJson(item)).toList(),
      completed: json['completed'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (difficulties != null) {
      data['difficulties'] = difficulties;
    }
    if (rate != null) {
      data['rate'] = rate;
    }
    if (fc != null) {
      data['fc'] = fc;
    }
    if (fs != null) {
      data['fs'] = fs;
    }
    if (songs != null) {
      data['songs'] = songs!.map((item) => item.toJson()).toList();
    }
    if (completed != null) {
      data['completed'] = completed;
    }
    return data;
  }
}

 

class CollectionRequiredSong {
  final int id;  //曲目 ID
  final String title;  //曲名
  final String type;  //谱面类型
  bool? completed; //值可空，要求的曲目是否完成
  List<int>? completedDifficulties; //值可空，已完成的难度

  CollectionRequiredSong({
    required this.id,
    required this.title,
    required this.type,
    this.completed,
    this.completedDifficulties,
  });

  factory CollectionRequiredSong.fromJson(Map<String, dynamic> json) {
    return CollectionRequiredSong(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      completed: json['completed'],
      completedDifficulties: (json['completed_difficulties'] as List<dynamic>?)?.where((item) => item != null).map((item) => item as int).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'title': title,
      'type': type,
    };
    if (completed != null) {
      data['completed'] = completed;
    }
    if (completedDifficulties != null) {
      data['completed_difficulties'] = completedDifficulties;
    }
    return data;
  }
}