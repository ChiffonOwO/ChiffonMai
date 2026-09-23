// 随身听 id 映射规则单测。
//
// 这里的规则全部来自对线上全量数据的实测（落雪 1344 首 × 水鱼 1394 首），
// 写在 `PortableSongMapService.dart` 文件头。映射写错的后果是「静默播错歌」或
// 「少一半歌」，两者在真机上都很难一眼看出来，所以必须有单测钉住。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/LuoXue/LuoXueSongEntity.dart';
import 'package:my_first_flutter_app/entity/Portable/PortableSong.dart';
import 'package:my_first_flutter_app/service/Portable/PortableSongMapService.dart';

// ── 测试夹具 ────────────────────────────────────────────────────────────────

LuoXueSong _lxnsSong({
  required int id,
  required String title,
  String artist = 'snow-artist',
  bool withDx = false,
}) {
  return LuoXueSong(
    id: id,
    title: title,
    artist: artist,
    genre: 'maimai',
    bpm: 150,
    version: 10000,
    difficulties: LuoXueSongDifficulties(
      standard: <LuoXueSongDifficulty>[
        LuoXueSongDifficulty(
          type: 'standard',
          difficulty: 3,
          level: '12',
          levelValue: 12,
          noteDesigner: '-',
          version: 10000,
        ),
      ],
      dx: <LuoXueSongDifficulty>[
        if (withDx)
          LuoXueSongDifficulty(
            type: 'dx',
            difficulty: 3,
            level: '13',
            levelValue: 13,
            noteDesigner: '-',
            version: 10000,
          ),
      ],
    ),
  );
}

Song _dfSong({
  required String id,
  required String title,
  String artist = 'fish-artist',
  String genre = '舞萌',
  int bpm = 150,
  String type = 'SD',
}) {
  return Song(
    id: id,
    title: title,
    type: type,
    ds: const <double>[12],
    level: const <String>['12'],
    cids: const <int>[1],
    charts: const <Chart>[],
    basicInfo: BasicInfo(
      title: title,
      artist: artist,
      genre: genre,
      bpm: bpm,
      releaseDate: '',
      from: 'maimai',
      isNew: false,
    ),
  );
}

PortableSong? _resolve(
  List<LuoXueSong> lxnsSongs,
  List<Song> dfSongs, {
  int index = 0,
  bool excludeUtage = true,
}) {
  final result = buildPortableLibrary(
    lxnsSongs: lxnsSongs,
    divingFishSongs: dfSongs,
    excludeUtage: excludeUtage,
  );
  if (result.songs.length <= index) return null;
  return result.songs[index];
}

/// 宴会场曲目专用的解析：默认规则会把它们排除掉，但要单独验证「id 取余」
/// 这类映射规则时仍然需要拿到结果（规则本身对非随身听场景依然有效，
/// 比如猜歌片段与谱面导出的音源下载）。
PortableSong? _resolveUtage(List<LuoXueSong> lxnsSongs, List<Song> dfSongs) =>
    _resolve(lxnsSongs, dfSongs, excludeUtage: false);

void main() {
  group('落雪 id → 水鱼 id 映射', () {
    test('规则①：水鱼 id = 落雪 id（标准曲）', () {
      final song = _resolve(
        [_lxnsSong(id: 8, title: 'True Love Song')],
        [_dfSong(id: '8', title: 'True Love Song', type: 'SD')],
      )!;
      expect(song.lxnsId, 8);
      expect(song.divingFishId, '8');
      expect(song.audioId, 8);
    });

    test('规则②：水鱼 id = 落雪 id + 10000（DX 曲）', () {
      // 实测：落雪 1001「BLACK ROSE」↔ 水鱼 11001「BLACK ROSE」
      final song = _resolve(
        [_lxnsSong(id: 1001, title: 'BLACK ROSE', withDx: true)],
        [_dfSong(id: '11001', title: 'BLACK ROSE', type: 'DX')],
      )!;
      expect(song.lxnsId, 1001);
      expect(song.divingFishId, '11001');
      // 音源文件名 = 水鱼 id % 10000
      expect(song.audioId, 1001);
      expect(song.audioUrl,
          'https://assets2.lxns.net/maimai/music/1001.mp3');
    });

    test('两条规则同时成立时优先取「落雪 id 原样」（id 更小、更规范）', () {
      // 实测存在这类曲目：水鱼里 X 与 X+10000 同名（同一首曲的两套谱面）
      final song = _resolve(
        [_lxnsSong(id: 30, title: 'ネコ日和。')],
        [
          _dfSong(id: '30', title: 'ネコ日和。', type: 'SD'),
          _dfSong(id: '10030', title: 'ネコ日和。', type: 'DX'),
        ],
      )!;
      expect(song.divingFishId, '30');
      expect(song.audioId, 30);
    });

    test('id=383 冲突：落雪「Link」不能串到水鱼「Link(CoF)」', () {
      // 实测这是两库共有 id 里唯一的异曲项。只按 id 匹配会串歌，
      // 所以必须同时校验曲名。这里水鱼没有「Link」，应回落规则②。
      final songs = buildPortableLibrary(
        lxnsSongs: [_lxnsSong(id: 383, title: 'Link')],
        divingFishSongs: [
          _dfSong(id: '383', title: 'Link(CoF)'),
          _dfSong(id: '10383', title: 'Link'),
        ],
      ).songs;
      expect(songs, hasLength(1));
      expect(songs.first.divingFishId, '10383');
      expect(songs.first.title, 'Link');
    });

    test('id=383 冲突：水鱼只有「Link(CoF)」时不应误配', () {
      final result = buildPortableLibrary(
        lxnsSongs: [_lxnsSong(id: 383, title: 'Link')],
        divingFishSongs: [_dfSong(id: '383', title: 'Link(CoF)')],
      );
      // 曲名不同 → 规则①②都不命中；规则③（只按曲名）也找不到「Link」→ 跳过
      expect(result.songs, isEmpty);
      expect(result.skippedCount, 1);
    });

    test('两处都查不到 → 不进列表并计入 skippedCount', () {
      final result = buildPortableLibrary(
        lxnsSongs: [
          _lxnsSong(id: 1815, title: 'IMBRUED:FLUX'),
          _lxnsSong(id: 9, title: 'Color My World'),
        ],
        divingFishSongs: [_dfSong(id: '9', title: 'Color My World')],
      );
      expect(result.songs, hasLength(1));
      expect(result.songs.first.lxnsId, 9);
      expect(result.skippedCount, 1);
    });
  });

  group('音源文件名（取余规则）', () {
    test('5 位 DX 曲取余：11466 → 1466.mp3', () {
      // 线上实测 11466.mp3 = 404、1466.mp3 = 200
      final song = _resolve(
        [_lxnsSong(id: 1466, title: '群青シグナル', withDx: true)],
        [_dfSong(id: '11466', title: '群青シグナル', type: 'DX')],
      )!;
      expect(song.audioId, 1466);
      expect(song.audioUrl,
          'https://assets2.lxns.net/maimai/music/1466.mp3');
    });

    test('6 位宴会场**同样取余**：100018 → 18.mp3', () {
      // 实测 62 首宴会场逐首验证：取余全部 200，原始 6 位全部 404。
      // 注意这与成绩 API 的 toLxnsSongId（宴会场原样保留）是**相反**的规则。
      //
      // 随身听默认不收录宴会场（见「排除宴会场」那组），所以这里要显式关掉过滤
      // 才拿得到条目 —— 这条规则本身对猜歌片段 / 谱面导出的音源下载仍然有效。
      final song = _resolveUtage(
        [_lxnsSong(id: 100018, title: '[協]Love You')],
        [_dfSong(id: '100018', title: '[協]Love You')],
      )!;
      expect(song.audioId, 18);
      expect(song.audioUrl, 'https://assets2.lxns.net/maimai/music/18.mp3');
    });

    test('4 位及以下取余后不变', () {
      final song = _resolve(
        [_lxnsSong(id: 834, title: 'Glorious Crown')],
        [_dfSong(id: '834', title: 'Glorious Crown')],
      )!;
      expect(song.audioId, 834);
    });
  });

  group('曲绘 id', () {
    test('本地 assets 用落雪 id（= 音源 id），网络 URL 左补零到 5 位', () {
      final song = _resolve(
        [_lxnsSong(id: 1466, title: '群青シグナル', withDx: true)],
        [_dfSong(id: '11466', title: '群青シグナル', type: 'DX')],
      )!;
      // 本地：assets/cover/1466.webp（已核实存在；11466.webp 不存在）
      expect(song.coverAssetId, 1466);
      // 网络：covers/11466.png（已核实 200）
      expect(song.coverNetworkId, '11466');
      expect(song.coverNetworkUrl,
          'https://www.diving-fish.com/covers/11466.png');
    });

    test('4 位曲目网络 URL 补零：8 → 00008.png', () {
      final song = _resolve(
        [_lxnsSong(id: 8, title: 'True Love Song')],
        [_dfSong(id: '8', title: 'True Love Song')],
      )!;
      expect(song.coverNetworkId, '00008');
    });

    test('6 位宴会场网络 URL：100018 → 100018.png（不取余）', () {
      // 实测 covers/100018.png = 200；取余成 18 会 404。
      // 注意与音源命名**相反**，这是最容易写错的一处。
      final song = _resolveUtage(
        [_lxnsSong(id: 100018, title: '[協]Love You')],
        [_dfSong(id: '100018', title: '[協]Love You')],
      )!;
      expect(song.coverNetworkId, '100018');
    });
  });

  group('列表粒度与排序（一首歌一行，不区分 SD/DX）', () {
    test('落雪一条曲目只产出一行，SD/DX 不重复', () {
      // 水鱼把同一首曲的 SD/DX 拆成两条记录，但落雪只有一条曲目 id，
      // 所以走落雪列表天然一首一行（用户已确认此粒度）。
      final result = buildPortableLibrary(
        lxnsSongs: [_lxnsSong(id: 1001, title: 'BLACK ROSE', withDx: true)],
        divingFishSongs: [
          _dfSong(id: '1001', title: 'BLACK ROSE', type: 'SD'),
          _dfSong(id: '11001', title: 'BLACK ROSE', type: 'DX'),
        ],
      );
      expect(result.songs, hasLength(1));
      expect(result.songs.first.lxnsId, 1001);
      // 有 DX 条目 → hasDx 标记为 true（列表上只做小标记，不拆行）
      expect(result.songs.first.hasDx, isTrue);
    });

    test('按规范化曲名排序：大小写/全角空格/全角括号不影响顺序', () {
      final result = buildPortableLibrary(
        lxnsSongs: [
          _lxnsSong(id: 3, title: 'banana'),
          _lxnsSong(id: 1, title: 'Apple'),
          _lxnsSong(id: 2, title: '　Apple　'),
        ],
        divingFishSongs: [
          _dfSong(id: '1', title: 'Apple'),
          _dfSong(id: '2', title: '　Apple　'),
          _dfSong(id: '3', title: 'banana'),
        ],
      );
      expect(result.songs.map((s) => s.lxnsId).toList(), <int>[1, 2, 3]);
    });

    test('歌名与艺术家取水鱼侧（落雪只在为空时兜底）', () {
      final song = _resolve(
        [_lxnsSong(id: 8, title: 'True Love Song', artist: 'snow')],
        [
          _dfSong(
            id: '8',
            title: 'True Love Song',
            artist: 'Kai/クラシック「G線上のアリア」',
            genre: '舞萌',
            bpm: 150,
          ),
        ],
      )!;
      expect(song.artist, 'Kai/クラシック「G線上のアリア」');
      expect(song.genre, '舞萌');
      expect(song.bpm, 150);
    });
  });

  group('排除宴会场', () {
    test('id >= 100000 的曲目不进列表', () {
      final result = buildPortableLibrary(
        lxnsSongs: [
          _lxnsSong(id: 100018, title: '[協]Love You'),
          _lxnsSong(id: 8, title: 'True Love Song'),
        ],
        divingFishSongs: [
          _dfSong(id: '100018', title: '[協]Love You'),
          _dfSong(id: '8', title: 'True Love Song'),
        ],
      );
      expect(result.songs, hasLength(1));
      expect(result.songs.first.lxnsId, 8);
      expect(result.excludedUtageCount, 1);
    });

    test('difficulties.utage 非空也算宴会场（即便 id 小于 100000）', () {
      // 实测两种判定线上完全一致（都是 62 首），但万一落雪以后补了宴会场却没填
      // id 区间，靠这一条兜住。
      final utageLowId = LuoXueSong(
        id: 5000,
        title: '宴会场假想曲',
        artist: 'a',
        genre: 'maimai',
        bpm: 150,
        version: 10000,
        difficulties: LuoXueSongDifficulties(
          standard: const <LuoXueSongDifficulty>[],
          utage: <LuoXueSongDifficultyUtage>[
            LuoXueSongDifficultyUtage(
              kanji: '協',
              description: '-',
              isBuddy: false,
            ),
          ],
        ),
      );
      final result = buildPortableLibrary(
        lxnsSongs: [utageLowId],
        divingFishSongs: [_dfSong(id: '5000', title: '宴会场假想曲')],
      );
      expect(result.songs, isEmpty);
      expect(result.excludedUtageCount, 1);
    });

    test('excludeUtage: false 时仍可保留宴会场（给需要全量的调用方留口子）', () {
      final result = buildPortableLibrary(
        lxnsSongs: [_lxnsSong(id: 100018, title: '[協]Love You')],
        divingFishSongs: [_dfSong(id: '100018', title: '[協]Love You')],
        excludeUtage: false,
      );
      expect(result.songs, hasLength(1));
      expect(result.excludedUtageCount, 0);
    });

    test('宴会场计数能往返落盘缓存', () {
      final result = buildPortableLibrary(
        lxnsSongs: [
          _lxnsSong(id: 100018, title: '[協]Love You'),
          _lxnsSong(id: 8, title: 'True Love Song'),
        ],
        divingFishSongs: [
          _dfSong(id: '100018', title: '[協]Love You'),
          _dfSong(id: '8', title: 'True Love Song'),
        ],
      );
      final restored =
          PortableLibraryResult.fromJsonString(json.encode(result.toJson()));
      expect(restored, isNotNull);
      expect(restored!.excludedUtageCount, 1);
      expect(restored.songs, hasLength(1));
    });
  });

  group('落盘缓存往返', () {
    test('toJson → fromJsonString 保持全部字段', () {
      final original = buildPortableLibrary(
        lxnsSongs: [
          _lxnsSong(id: 1001, title: 'BLACK ROSE', withDx: true),
          _lxnsSong(id: 8, title: 'True Love Song'),
        ],
        divingFishSongs: [
          _dfSong(id: '11001', title: 'BLACK ROSE', type: 'DX'),
          _dfSong(id: '8', title: 'True Love Song'),
        ],
      );
      final restored =
          PortableLibraryResult.fromJsonString(jsonEncodeLibrary(original));
      expect(restored, isNotNull);
      expect(restored!.songs.length, original.songs.length);
      expect(restored.skippedCount, original.skippedCount);
      final a = original.songs.first;
      final b = restored.songs.first;
      expect(b.lxnsId, a.lxnsId);
      expect(b.divingFishId, a.divingFishId);
      expect(b.audioId, a.audioId);
      expect(b.title, a.title);
      expect(b.artist, a.artist);
      expect(b.hasDx, a.hasDx);
    });

    test('坏数据返回 null 而不是抛异常', () {
      expect(PortableLibraryResult.fromJsonString('not json'), isNull);
      expect(PortableLibraryResult.fromJsonString('{}'), isNull);
      expect(PortableLibraryResult.fromJsonString('{"songs":[]}'), isNull);
    });
  });
}

String jsonEncodeLibrary(PortableLibraryResult result) =>
    json.encode(result.toJson());
