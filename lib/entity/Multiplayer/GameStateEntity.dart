import 'GuessRecord.dart';
import 'PlayerEntity.dart';

class GameStateEntity {
  final int currentRound;
  final int totalRounds;
  final dynamic targetSong;
  final List<GuessRecord> guesses;
  final int timeRemaining;
  final bool isGameOver;
  final bool isRoundOver;
  final int maxGuesses;
  final int currentGuesses;

  /// 本回合时间限制（秒）。服务器随 gameState 下发，用于让本地倒计时
  /// 与房间设置一致（原先只带 timeRemaining，客户端缺省 60，房间设 30 秒时
  /// 倒计时会一直从 60 开始）。
  final int timeLimit;

  /// 本回合全部目标曲（letters 模式会有多首，其它模式长度为 1）
  final List<dynamic> targetSongs;

  /// letters 模式：房间共享的已开字母
  final List<String> openedLetters;

  /// letters 模式：各曲目当前的掩码（songId -> 形如「リ□□□□」的字符串）
  final Map<String, String> maskedTitles;

  /// letters 模式：本回合已猜中的曲目 id
  final List<String> foundSongIds;

  /// 各玩家在当前回合的分数快照。
  ///
  /// 服务端 getGameState() 会带 players，且这份数据是**结算之后**生成的
  /// （endRoundHandler 先 room.endRound() 再广播 round_over）——
  /// 而 round_over 之前的那条 room_updated 是在结算前发的。也就是说
  /// room.players 里的分数永远慢一回合，排行榜必须以这里的快照为准，
  /// 否则会出现「答对横幅 +62 分、排行榜还是上一回合分数」的错位。
  final List<PlayerEntity> players;

  /// 本局获胜者的 playerId 列表（服务端在 status === 'ended' 时才下发）。
  ///
  /// 由服务端判定而不是客户端自己「按分数排个序取第一名」，是因为：
  /// - 客户端用 `List.sort` 排序，Dart 不保证稳定，同分玩家名次会来回跳；
  /// - 同分应当是并列获胜，靠排序先后决定赢家是错的。
  /// 空列表表示「平局」或「还没结束」——两者由 [isGameOver] 区分。
  final List<String> winners;

  GameStateEntity({
    required this.currentRound,
    required this.totalRounds,
    this.targetSong,
    required this.guesses,
    required this.timeRemaining,
    required this.isGameOver,
    required this.isRoundOver,
    this.maxGuesses = 10,
    this.currentGuesses = 0,
    this.timeLimit = 60,
    this.targetSongs = const [],
    this.openedLetters = const [],
    this.maskedTitles = const {},
    this.foundSongIds = const [],
    this.players = const [],
    this.winners = const [],
  });

  factory GameStateEntity.fromJson(Map<String, dynamic> json) {
    List<dynamic>? guessesJson = json['guesses'] as List<dynamic>?;
    List<GuessRecord> guessesList = [];
    if (guessesJson != null) {
      guessesList = guessesJson.map((e) => GuessRecord.fromJson(e)).toList();
    }

    // 注意：必须是显式构造的 Map<String, String>。
    // json.decode 出来的 Map 是 Map<dynamic, dynamic>，直接 .map() 得到的也是
    // Map<dynamic, dynamic>，赋给 Map<String, String> 字段会在运行时抛
    // 「type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, String>'」。
    final Map<String, String> maskedTitles = {};
    final dynamic rawMasked =
        json['maskedTitles'] ?? json['masked_titles'];
    if (rawMasked is Map) {
      rawMasked.forEach((k, v) {
        if (k != null && v != null) {
          maskedTitles[k.toString()] = v.toString();
        }
      });
    }

    final List<String> openedLetters = <String>[];
    final dynamic rawOpened =
        json['openedLetters'] ?? json['opened_letters'];
    if (rawOpened is List) {
      for (final item in rawOpened) {
        if (item != null) openedLetters.add(item.toString());
      }
    }

    final List<String> foundSongIds = <String>[];
    final dynamic rawFound =
        json['foundSongIds'] ?? json['found_song_ids'];
    if (rawFound is List) {
      for (final item in rawFound) {
        if (item != null) foundSongIds.add(item.toString());
      }
    }

    final List<dynamic> targetSongs = <dynamic>[];
    final dynamic rawTargets =
        json['targetSongs'] ?? json['target_songs'];
    if (rawTargets is List) targetSongs.addAll(rawTargets);

    final List<String> winners = <String>[];
    final dynamic rawWinners = json['winners'];
    if (rawWinners is List) {
      for (final item in rawWinners) {
        if (item != null) winners.add(item.toString());
      }
    }

    // 同上：json.decode 出来是 Map<dynamic, dynamic>，必须显式转成
    // Map<String, dynamic> 再交给 fromJson，否则运行时类型断言会炸。
    final List<PlayerEntity> players = <PlayerEntity>[];
    final dynamic rawPlayers = json['players'];
    if (rawPlayers is List) {
      for (final item in rawPlayers) {
        if (item is Map) {
          players.add(PlayerEntity.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    
    return GameStateEntity(
      currentRound: json['currentRound'] ?? json['current_round'] ?? 1,
      totalRounds: json['totalRounds'] ?? json['total_round'] ?? 5,
      targetSong: json['targetSong'] ?? json['target_song'] ?? json['currentSong'] ?? json['current_song'],
      guesses: guessesList,
      timeRemaining: json['timeRemaining'] ?? json['time_remaining'] ?? 60,
      isGameOver: json['isGameOver'] ?? json['is_game_over'] ?? false,
      isRoundOver: json['isRoundOver'] ?? json['is_round_over'] ?? false,
      maxGuesses: json['max_guesses'] ?? json['maxGuesses'] ?? 10,
      currentGuesses: json['current_guesses'] ?? json['currentGuesses'] ?? 0,
      timeLimit: json['timeLimit'] ?? json['time_limit'] ?? 60,
      targetSongs: targetSongs,
      openedLetters: openedLetters,
      maskedTitles: maskedTitles,
      foundSongIds: foundSongIds,
      players: players,
      winners: winners,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_round': currentRound,
      'total_rounds': totalRounds,
      'target_song': targetSong,
      'guesses': guesses.map((g) => g.toJson()).toList(),
      'time_remaining': timeRemaining,
      'is_game_over': isGameOver,
      'is_round_over': isRoundOver,
      'max_guesses': maxGuesses,
      'current_guesses': currentGuesses,
      'time_limit': timeLimit,
      'target_songs': targetSongs,
      'opened_letters': openedLetters,
      'masked_titles': maskedTitles,
      'found_song_ids': foundSongIds,
      'players': players.map((p) => p.toJson()).toList(),
      'winners': winners,
    };
  }

  GameStateEntity copyWith({
    int? currentRound,
    int? totalRounds,
    dynamic targetSong,
    List<GuessRecord>? guesses,
    int? timeRemaining,
    bool? isGameOver,
    bool? isRoundOver,
    int? maxGuesses,
    int? currentGuesses,
    int? timeLimit,
    List<dynamic>? targetSongs,
    List<String>? openedLetters,
    Map<String, String>? maskedTitles,
    List<String>? foundSongIds,
    List<PlayerEntity>? players,
    List<String>? winners,
  }) {
    return GameStateEntity(
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      targetSong: targetSong ?? this.targetSong,
      guesses: guesses ?? this.guesses,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isGameOver: isGameOver ?? this.isGameOver,
      isRoundOver: isRoundOver ?? this.isRoundOver,
      maxGuesses: maxGuesses ?? this.maxGuesses,
      currentGuesses: currentGuesses ?? this.currentGuesses,
      timeLimit: timeLimit ?? this.timeLimit,
      targetSongs: targetSongs ?? this.targetSongs,
      openedLetters: openedLetters ?? this.openedLetters,
      maskedTitles: maskedTitles ?? this.maskedTitles,
      foundSongIds: foundSongIds ?? this.foundSongIds,
      players: players ?? this.players,
      winners: winners ?? this.winners,
    );
  }
}
