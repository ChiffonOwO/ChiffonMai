import 'GuessRecord.dart';

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
  });

  factory GameStateEntity.fromJson(Map<String, dynamic> json) {
    List<dynamic>? guessesJson = json['guesses'] as List<dynamic>?;
    List<GuessRecord> guessesList = [];
    if (guessesJson != null) {
      guessesList = guessesJson.map((e) => GuessRecord.fromJson(e)).toList();
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
    );
  }
}