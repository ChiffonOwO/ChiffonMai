class GuessRecord {
  final String playerId;
  final String playerNickname;
  final String songId;
  final String songName;
  final bool isCorrect;
  final int score;
  final DateTime guessedAt;

  GuessRecord({
    required this.playerId,
    required this.playerNickname,
    required this.songId,
    required this.songName,
    required this.isCorrect,
    required this.score,
    required this.guessedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'player_nickname': playerNickname,
      'song_id': songId,
      'song_name': songName,
      'is_correct': isCorrect,
      'score': score,
      'guessed_at': guessedAt.toIso8601String(),
    };
  }

  factory GuessRecord.fromJson(Map<String, dynamic> json) {
    return GuessRecord(
      playerId: json['player_id'] ?? json['playerId'] ?? '',
      playerNickname: json['player_nickname'] ?? json['playerNickname'] ?? '',
      songId: json['song_id'] ?? json['songId'] ?? '',
      songName: json['song_name'] ?? json['songName'] ?? '',
      // 服务端下发的键是 `correct`（见 server 的 addGuess / getGameState），
      // 只认 `is_correct`/`isCorrect` 的话每一条猜对记录都会被解析成 false，
      // 表现为「答对了但历史记录显示答错、本地分数不涨」。
      isCorrect: json['correct'] ?? json['is_correct'] ?? json['isCorrect'] ?? false,
      score: json['score'] ?? 0,
      guessedAt: json['guessed_at'] != null 
          ? DateTime.parse(json['guessed_at']) 
          : json['guessedAt'] != null 
              ? DateTime.parse(json['guessedAt']) 
              : DateTime.now(),
    );
  }
}
