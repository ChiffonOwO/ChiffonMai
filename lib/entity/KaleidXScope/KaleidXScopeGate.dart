/// 万花镜（KaleidXScope）门数据模型
///
/// 对应服务端 GET /api/kaleidxscope/gates/:color 返回的完整数据

class ChallengePhase {
  final String startDate;
  final String? endDate;
  final String difficulty;
  final int lifeTarget;
  final int? target;

  ChallengePhase({
    required this.startDate,
    this.endDate,
    required this.difficulty,
    required this.lifeTarget,
    this.target,
  });

  factory ChallengePhase.fromJson(Map<String, dynamic> json) {
    return ChallengePhase(
      startDate: (json['startDate'] as String?) ?? '',
      endDate: json['endDate'] as String?,
      difficulty: (json['difficulty'] as String?) ?? '',
      lifeTarget: (json['lifeTarget'] as num?)?.toInt() ?? 1,
      target: (json['target'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'endDate': endDate,
        'difficulty': difficulty,
        'lifeTarget': lifeTarget,
        if (target != null) 'target': target,
      };
}

class KaleidXScopeChallenge {
  final String name;
  final List<ChallengePhase> phases;

  KaleidXScopeChallenge({required this.name, required this.phases});

  factory KaleidXScopeChallenge.fromJson(Map<String, dynamic> json) {
    return KaleidXScopeChallenge(
      name: (json['name'] as String?) ?? '',
      phases: (json['phases'] as List<dynamic>?)
              ?.map((e) => ChallengePhase.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phases': phases.map((p) => p.toJson()).toList(),
      };
}

class KaleidXScopeSpecialSong {
  final int songId;
  final String role;

  KaleidXScopeSpecialSong({required this.songId, required this.role});

  factory KaleidXScopeSpecialSong.fromJson(Map<String, dynamic> json) {
    return KaleidXScopeSpecialSong(
      songId: (json['songId'] as num?)?.toInt() ?? 0,
      role: (json['role'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'songId': songId, 'role': role};
}

class KaleidXScopeGate {
  final int id;
  final String color;
  final String name;
  final String? displayName;
  final String? doorName;
  final String? prerequisite;
  final String? keyRequirement;
  final String? track1Desc;
  final String? track2Desc;
  final String? track3Desc;
  final String? guideNote;
  final String? frameImageUrl;
  final int? frameCollectionId;
  final String? frameCollectionType;
  final Map<String, List<int>> songs;
  final List<KaleidXScopeChallenge> challenges;
  final List<KaleidXScopeSpecialSong> specialSongs;

  KaleidXScopeGate({
    required this.id,
    required this.color,
    required this.name,
    this.displayName,
    this.doorName,
    this.prerequisite,
    this.keyRequirement,
    this.track1Desc,
    this.track2Desc,
    this.track3Desc,
    this.guideNote,
    this.frameImageUrl,
    this.frameCollectionId,
    this.frameCollectionType,
    required this.songs,
    required this.challenges,
    required this.specialSongs,
  });

  factory KaleidXScopeGate.fromJson(Map<String, dynamic> json) {
    // 解析 songs Map
    final Map<String, List<int>> songs = {};
    if (json['songs'] is Map<String, dynamic>) {
      (json['songs'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
          songs[key] = value.map((e) => (e as num).toInt()).toList();
        }
      });
    }

    return KaleidXScopeGate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      color: (json['color'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      displayName: json['displayName'] as String?,
      doorName: json['doorName'] as String?,
      prerequisite: json['prerequisite'] as String?,
      keyRequirement: json['keyRequirement'] as String?,
      track1Desc: json['track1Desc'] as String?,
      track2Desc: json['track2Desc'] as String?,
      track3Desc: json['track3Desc'] as String?,
      guideNote: json['guideNote'] as String?,
      frameImageUrl: json['frameImageUrl'] as String?,
      frameCollectionId: (json['frameCollectionId'] as num?)?.toInt(),
      frameCollectionType: json['frameCollectionType'] as String?,
      songs: songs,
      challenges: (json['challenges'] as List<dynamic>?)
              ?.map(
                  (e) => KaleidXScopeChallenge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      specialSongs: (json['specialSongs'] as List<dynamic>?)
              ?.map((e) =>
                  KaleidXScopeSpecialSong.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color,
        'name': name,
        'displayName': displayName,
        'doorName': doorName,
        'prerequisite': prerequisite,
        'keyRequirement': keyRequirement,
        'track1Desc': track1Desc,
        'track2Desc': track2Desc,
        'track3Desc': track3Desc,
        'guideNote': guideNote,
        'frameImageUrl': frameImageUrl,
        'frameCollectionId': frameCollectionId,
        'frameCollectionType': frameCollectionType,
        'songs': songs,
        'challenges': challenges.map((c) => c.toJson()).toList(),
        'specialSongs': specialSongs.map((s) => s.toJson()).toList(),
      };
}
