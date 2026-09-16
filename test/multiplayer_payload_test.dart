// 多人猜歌游戏 —— 客户端解析契约测试
//
// 报文来自真实服务器的采集结果（test/fixtures/mp_payloads.json），
// 用来锁住「服务端下发的字段」与「客户端实体解析」之间的一致性：
// 一旦任一侧改了字段名/结构，这里会立刻失败，而不是等到真机上表现成
// 「倒计时从 60 开始」「开字母一直空白」这类难查的问题。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameStateEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GuessRecord.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';

const List<String> _modes = [
  'info', 'cover', 'blurred', 'audio', 'alia', 'letters',
  'flash', 'tileReveal', 'chartPeek',
];

// 采集结果里存在两种层级，必须分开取：
//   fixtures[mode]['round_start']            → 直接就是 payload
//   fixtures['${mode}_round_over']           → 整条报文 {action, payload}
/// 取出整条报文的 `payload`。
Map<String, dynamic> _payload(Map<String, dynamic> message) {
  final payload = message['payload'];
  if (payload is! Map) {
    throw StateError('报文缺少 payload 字段（action=${message['action']}）');
  }
  return Map<String, dynamic>.from(payload);
}

/// 从 payload 里取出 gameState。
Map<String, dynamic> _stateOfPayload(Map<String, dynamic> payload) {
  final state = payload['gameState'];
  if (state is! Map) {
    throw StateError('payload 缺少 gameState');
  }
  return Map<String, dynamic>.from(state);
}

/// 从整条报文里取出 gameState。
Map<String, dynamic> _stateOfMessage(Map<String, dynamic> message) =>
    _stateOfPayload(_payload(message));

void main() {
  final file = File('test/fixtures/mp_payloads.json');
  final Map<String, dynamic> fixtures =
      json.decode(file.readAsStringSync()) as Map<String, dynamic>;

  group('房间报文解析', () {
    for (final mode in _modes) {
      test('$mode: room_created / round_start 可解析', () {
        final entry = fixtures[mode] as Map<String, dynamic>;
        final room = RoomEntity.fromJson(
            ((entry['room_created'] as Map)['room']) as Map<String, dynamic>);
        expect(room.roomId, isNotEmpty);
        expect(room.roomCode.length, 6, reason: '房间码应为 6 位');
        expect(room.gameType.apiKey, mode, reason: '游戏类型应与创建时一致');
        expect(room.timeLimit, 40, reason: '房间设置的时间限制应回传');
        expect(room.maxGuesses, 10);

        final state = GameStateEntity.fromJson(
            _stateOfPayload(entry['round_start'] as Map<String, dynamic>));
        expect(state.currentRound, 1);
        expect(state.totalRounds, 2);
        expect(state.targetSong, isNotNull, reason: 'round_start 应带目标歌曲');
      });
    }
  });

  group('倒计时字段', () {
    for (final mode in _modes) {
      test('$mode: timeRemaining / timeLimit 均已下发', () {
        final entry = fixtures[mode] as Map<String, dynamic>;
        final state = GameStateEntity.fromJson(
            _stateOfPayload(entry['round_start'] as Map<String, dynamic>));
        // 这两个字段缺失会让客户端倒计时回落到默认 60 秒
        expect(state.timeLimit, 40, reason: 'timeLimit 应随 gameState 下发');
        expect(state.timeRemaining, greaterThan(0), reason: 'timeRemaining 应有值');
        expect(state.timeRemaining, lessThanOrEqualTo(40),
            reason: 'timeRemaining 不应超过房间设置');
      });
    }
  });

  group('猜测记录', () {
    // letters 模式走的是「开字母 + 猜歌」流程，采集时没有单独抓 wrong/right
    // 报文，它的猜测记录在下面的 letters 分组里单独验证。
    const guessModes = [
      'info', 'cover', 'blurred', 'audio', 'alia',
      'flash', 'tileReveal', 'chartPeek',
    ];
    for (final mode in guessModes) {
      test('$mode: 猜错的记录判 false 且得 0 分', () {
        final guess = GuessRecord.fromJson(
            _payload(fixtures['${mode}_wrong_guess'] as Map<String, dynamic>)['guess']
                as Map<String, dynamic>);
        expect(guess.isCorrect, isFalse);
        expect(guess.score, 0);
        expect(guess.playerNickname, isNotEmpty);
        expect(guess.songName, isNotEmpty);
      });

      test('$mode: 猜对的记录判 true 且分数在合理范围', () {
        final guess = GuessRecord.fromJson(
            _payload(fixtures['${mode}_right_guess'] as Map<String, dynamic>)['guess']
                as Map<String, dynamic>);
        expect(guess.isCorrect, isTrue);
        // 得分上限 100（立即作答），下限 10
        expect(guess.score, inInclusiveRange(10, 100),
            reason: '得分应带速度奖励且不低于下限，实际=${guess.score}');
      });
    }
  });

  group('回合结束状态', () {
    for (final mode in [
      'info', 'cover', 'blurred', 'audio', 'alia',
      'flash', 'tileReveal', 'chartPeek',
    ]) {
      test('$mode: round_over 后 isRoundOver=true', () {
        final state = GameStateEntity.fromJson(
            _stateOfMessage(
                fixtures['${mode}_round_over'] as Map<String, dynamic>));
        expect(state.isRoundOver, isTrue);
        expect(state.isGameOver, isFalse, reason: '还有后续回合');
      });
    }
  });

  group('letters 开字母字段', () {
    test('round_start 下发多首目标曲', () {
      final entry = fixtures['letters'] as Map<String, dynamic>;
      final state = GameStateEntity.fromJson(
          _stateOfPayload(entry['round_start'] as Map<String, dynamic>));
      expect(state.targetSongs.length, 3, reason: 'songCount=3 应抽 3 首');
      expect(state.maskedTitles.length, 3, reason: '每首曲目都应有掩码');
      expect(state.openedLetters, isEmpty, reason: '开局尚未开任何字母');
      expect(state.foundSongIds, isEmpty);
    });

    test('初始掩码为 □，不含曲名原文', () {
      final entry = fixtures['letters'] as Map<String, dynamic>;
      final state = GameStateEntity.fromJson(
          _stateOfPayload(entry['round_start'] as Map<String, dynamic>));
      for (final masked in state.maskedTitles.values) {
        expect(masked.contains('□') || masked.trim().isEmpty, isTrue,
            reason: '未开字母时掩码应全是占位符，实际=$masked');
      }
    });

    test('开字母后掩码揭示对应字符', () {
      final afterOpen = GameStateEntity.fromJson(
          _stateOfMessage(
              fixtures['letters_after_open'] as Map<String, dynamic>));
      final opened = afterOpen.openedLetters;
      expect(opened, isNotEmpty, reason: '应记录已开字母');

      final letter = opened.last;
      final changed = afterOpen.maskedTitles.values
          .where((m) => m.contains(letter))
          .toList();
      expect(changed, isNotEmpty,
          reason: '开字母「$letter」后，至少一个掩码应包含该字符');
    });

    test('猜中一首后 foundSongIds 增加，且该曲公开完整曲名', () {
      final before = GameStateEntity.fromJson(
          _stateOfMessage(
              fixtures['letters_after_open'] as Map<String, dynamic>));
      final afterGuess = GameStateEntity.fromJson(
          _stateOfMessage(
              fixtures['letters_after_guess'] as Map<String, dynamic>));

      expect(afterGuess.foundSongIds.length, greaterThan(before.foundSongIds.length),
          reason: '猜中后应记录到 foundSongIds');
      final foundId = afterGuess.foundSongIds.last;
      final masked = afterGuess.maskedTitles[foundId]!;
      expect(masked.contains('□'), isFalse,
          reason: '已猜中的曲目应公开完整曲名，实际=$masked');
    });

    test('猜中一首不结束回合（还有未猜中的曲目）', () {
      final afterGuess = GameStateEntity.fromJson(
          _stateOfMessage(
              fixtures['letters_after_guess'] as Map<String, dynamic>));
      expect(afterGuess.isRoundOver, isFalse,
          reason: 'letters 需全部猜中才结束回合');
    });

    test('letters 的猜中记录同样判 true 且得分在合理范围', () {
      final guess = GuessRecord.fromJson(
          _payload(fixtures['letters_guess'] as Map<String, dynamic>)['guess']
              as Map<String, dynamic>);
      expect(guess.isCorrect, isTrue);
      expect(guess.score, inInclusiveRange(10, 100),
          reason: '得分应带速度奖励且不低于下限，实际=${guess.score}');
      expect(guess.playerNickname, isNotEmpty);
      expect(guess.songName, isNotEmpty);
    });

    test('开字母回执带 letter 与 openedLetters', () {
      final receipt = _payload(
          fixtures['letters_letter_opened'] as Map<String, dynamic>);
      expect(receipt['success'], isTrue);
      expect(receipt['letter'], isNotEmpty);
      expect((receipt['openedLetters'] as List), isNotEmpty);
    });
  });
  group('已结算分数快照', () {
    // 回归：服务端 endRoundHandler 是先结算再广播 round_over，
    // 而结算前那条 room_updated 早就发出去了。客户端排行榜如果读
    // room.players 就会永远慢一回合（真机上表现为「答对了! +62分」
    // 下面排行榜还停在上一回合的分数）。gameState.players 是结算后的
    // 快照，必须能解析出来。
    for (final mode in _modes) {
      test('$mode: gameState.players 可解析且分数为整数', () {
        final state = GameStateEntity.fromJson(
            _stateOfPayload((fixtures[mode] as Map<String, dynamic>)['round_start']
                as Map<String, dynamic>));
        expect(state.players, isNotEmpty,
            reason: 'gameState 应下发玩家分数快照');
        for (final player in state.players) {
          expect(player.playerId, isNotEmpty);
          expect(player.nickname, isNotEmpty);
          expect(player.score, greaterThanOrEqualTo(0));
        }
      });
    }

    for (final mode in _modes) {
      test('$mode: round_over 的玩家分数是结算后的值', () {
        final over = fixtures['${mode}_round_over'];
        if (over == null) return;
        final state = GameStateEntity.fromJson(
            _stateOfMessage(over as Map<String, dynamic>));
        expect(state.players, isNotEmpty);
        // 结算后至少要有人拿到分（采集脚本里每个模式都完成了一回合）
        final total = state.players
            .map((p) => p.score)
            .fold<int>(0, (acc, s) => acc + s);
        expect(total, greaterThan(0),
            reason: 'round_over 快照应含本回合结算出来的分数');
      });
    }

    test('players 缺省时为空列表（老服务端兼容）', () {
      final state = GameStateEntity.fromJson({
        'currentRound': 1,
        'totalRounds': 1,
        'guesses': <dynamic>[],
        'timeRemaining': 10,
        'isGameOver': false,
        'isRoundOver': false,
      });
      expect(state.players, isEmpty);
    });
  });

  group('胜负判定字段', () {
    // 胜负由服务端 winners 下发，客户端不再自己按分数排序取第一名：
    // Dart 的 List.sort 不保证稳定，同分玩家名次会来回跳，而同分本应并列获胜。
    Map<String, dynamic> gameOverState({
      required List<String> winners,
      required List<Map<String, dynamic>> players,
    }) =>
        {
          'currentRound': 2,
          'totalRounds': 2,
          'guesses': <dynamic>[],
          'timeRemaining': 0,
          'isGameOver': true,
          'isRoundOver': true,
          'players': players,
          'winners': winners,
        };

    test('单一获胜者可解析', () {
      final state = GameStateEntity.fromJson(gameOverState(
        winners: ['p1'],
        players: [
          {'id': 'p1', 'nickname': '甲', 'score': 180},
          {'id': 'p2', 'nickname': '乙', 'score': 40},
        ],
      ));
      expect(state.isGameOver, isTrue);
      expect(state.winners, ['p1']);
    });

    test('同分并列时 winners 含多人', () {
      final state = GameStateEntity.fromJson(gameOverState(
        winners: ['p1', 'p2'],
        players: [
          {'id': 'p1', 'nickname': '甲', 'score': 100},
          {'id': 'p2', 'nickname': '乙', 'score': 100},
        ],
      ));
      expect(state.winners, ['p1', 'p2'],
          reason: '同分应并列获胜，不能靠排序先后定输赢');
    });

    test('全场无人得分时 winners 为空（平局）', () {
      final state = GameStateEntity.fromJson(gameOverState(
        winners: <String>[],
        players: [
          {'id': 'p1', 'nickname': '甲', 'score': 0},
          {'id': 'p2', 'nickname': '乙', 'score': 0},
        ],
      ));
      expect(state.isGameOver, isTrue);
      expect(state.winners, isEmpty,
          reason: '全员 0 分是平局，不是「获胜」');
    });

    test('回合进行中不含 winners（避免提前弹获胜）', () {
      final state = GameStateEntity.fromJson({
        'currentRound': 1,
        'totalRounds': 2,
        'guesses': <dynamic>[],
        'timeRemaining': 20,
        'isGameOver': false,
        'isRoundOver': false,
      });
      expect(state.isGameOver, isFalse);
      expect(state.winners, isEmpty);
    });

    test('老服务端不下发 winners 时降级为空列表', () {
      final state = GameStateEntity.fromJson({
        'currentRound': 2,
        'totalRounds': 2,
        'guesses': <dynamic>[],
        'timeRemaining': 0,
        'isGameOver': true,
        'isRoundOver': true,
      });
      expect(state.winners, isEmpty);
    });
  });

  group('游戏模式枚举', () {
    test('apiKey 与服务器约定的九种取值一致', () {
      expect(GameType.info.apiKey, 'info');
      expect(GameType.cover.apiKey, 'cover');
      expect(GameType.blurred.apiKey, 'blurred');
      expect(GameType.audio.apiKey, 'audio');
      expect(GameType.alia.apiKey, 'alia');
      expect(GameType.letters.apiKey, 'letters');
      expect(GameType.flash.apiKey, 'flash');
      expect(GameType.tileReveal.apiKey, 'tileReveal');
      expect(GameType.chartPeek.apiKey, 'chartPeek');
    });

    test('中文显示名与单人猜歌页对齐', () {
      expect(GameType.flash.name, '曲绘快闪');
      expect(GameType.tileReveal.name, '曲绘拼图');
      expect(GameType.chartPeek.name, '谱面片段');
    });
  });

  group('新模式的模式专属设置', () {
    // flash / tileReveal / chartPeek 的题面由客户端按房间设置渲染，
    // 参数必须原样从服务端回传到每一个客户端，否则各端看到的题面不一致。
    for (final mode in ['flash', 'tileReveal', 'chartPeek']) {
      test('$mode: room_created 带回模式专属设置', () {
        final entry = fixtures[mode] as Map<String, dynamic>;
        final room = RoomEntity.fromJson(
            ((entry['room_created'] as Map)['room']).cast<String, dynamic>());
        expect(room.gameType.apiKey, mode);
        expect(room.flashDurationMs, 800);
        expect(room.tileCount, 1600);
        expect(room.tileRevealIntervalMs, 900);
        expect(room.peekDurationSeconds, 12);
        expect(room.peekDifficulties, ['3', '4']);
      });
    }

    test('缺省时回落到与单人设置一致的默认值', () {
      final room = RoomEntity.fromJson({
        'id': 'r1',
        'game_type': 'chartPeek',
        'players': <dynamic>[],
      });
      expect(room.flashDurationMs, 300);
      expect(room.tileCount, 1000);
      expect(room.tileRevealIntervalMs, 1500);
      expect(room.peekDurationSeconds, 8);
      expect(room.peekDifficulties, ['4'],
          reason: '难度池缺省应与单人谱面片段猜歌一致（EXPERT）');
    });

    test('中文游戏类型名也能解析（兼容旧服务端）', () {
      expect(RoomEntity.fromJson({'id': 'r', 'game_type': '曲绘快闪'}).gameType,
          GameType.flash);
      expect(RoomEntity.fromJson({'id': 'r', 'game_type': '曲绘拼图'}).gameType,
          GameType.tileReveal);
      expect(RoomEntity.fromJson({'id': 'r', 'game_type': '谱面片段'}).gameType,
          GameType.chartPeek);
    });
  });
}
