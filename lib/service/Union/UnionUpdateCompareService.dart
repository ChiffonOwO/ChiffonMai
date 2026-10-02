import '../../entity/DivingFish/Song.dart';
import '../../utils/SongFilterUtil.dart';

/// 「国服更新对照」的结果：把本地曲库按**国服（水鱼）更新前沿**切成三块。
///
/// 背景（这是本功能存在的理由）：
///   * 曲目详情页显示的「首次上线」是**日服**首发日期（水鱼与 union 给的都是
///     日服时间），国服玩家光看这个数字判断不出「这首歌我这边上了没有」；
///   * 水鱼（`music_data`）是**国服目前的全量歌曲**，union（`/api/union/musics`）
///     是**全量歌曲**（含日服已上、国服未上的），合并时后者独有的会被打上
///     `Song.isExtra = true`（见 `MaimaiMusicDataManager.fetchAndUpdateMusicData`）；
///   * 于是「union 独有 且 id 比国服最新曲更大」= **下次更新最可能上的歌**。
///
/// 判据（2026-09 用真实数据核对过）：排除 5 首超前上线曲目后，水鱼最新常规曲
/// id = 11878（Pixel Galaxy），union 独有里 id > 11878 的常规曲 155 首，
/// 从 11879 一路到最新 —— id 递增与日服上线顺序基本一致，
/// 所以「最大 id 即最新」成立。
///
/// ⚠️ 宴会场（6 位 id）必须排除在「最新」的判定之外：它的 id 是 1xxxxx，
/// 一旦参与，前沿会被顶到十万位，所有常规新曲都会被误判成「国服已上线」。
class UnionUpdateCompare {
  const UnionUpdateCompare({
    required this.frontier,
    required this.upcoming,
    required this.skipped,
    required this.utage,
    required this.cnSongs,
    required this.earlyReleases,
    required this.cnSongCount,
    required this.cnRegularCount,
    required this.maidataCount,
  });

  /// 国服（水鱼）当前最新的**常规**曲；曲库为空时为 null。
  final Song? frontier;

  /// union 独有、id 比 [frontier] 更大的常规曲 → 近期更新最可能上的歌（id 升序）。
  ///
  /// 升序不是随手排的：国服是一批一批往前补的，**id 最小 = 日服上得最早 =
  /// 最可能先补上**，所以列表第一屏就该是这个顺序。
  final List<Song> upcoming;

  /// union 独有、但 id 比 [frontier] 还小的常规曲（id 升序）。
  ///
  /// 这些多半是**区域限定 / 国服跳过**的曲子（联动曲、日服独占），
  /// 也可能只是 union 的 id 顺序有偏差 —— 单独一段展示，并如实说明不确定性。
  final List<Song> skipped;

  /// union 独有的宴会场（6 位 id）。宴会场不按版本更新，单独一段。
  final List<Song> utage;

  /// 水鱼（国服）曲数，**含宴会场**。
  ///
  /// 记账必须合得上：`unionSongCount == cnSongCount + 三段 union 独有`，
  /// 与 union 全量源（`/api/union/musics`）的条数一致（实测 1885 = 1394 + 491）。
  final int cnSongCount;

  /// 水鱼里 id < 100000 的常规曲数 —— [frontier] 就是从这一堆里取的最大 id。
  final int cnRegularCount;

  /// 水鱼（国服）的常规曲，**按 id 降序**：第一首就是 [frontier]。
  ///
  /// 留着它是为了在「union 全量源」里就地看见前沿在哪 —— 用户从国服最新曲
  /// 往回翻，再切到「待上线」就是紧挨着的下一批。
  /// **不含**超前上线曲目（那些在 [earlyReleases] 里）。
  final List<Song> cnSongs;

  /// 国服**超前上线**的曲目（国服先于日服上线，id 却排在最新）。
  ///
  /// 它们是国服已经有的曲子（算进 [cnSongCount]），但**不能参与前沿判定**：
  /// 一旦参与，前沿会被顶到它们身上，把真正还没补上的那批曲子挡在候选之外。
  /// 实测这三首（11944/11945/11946）会把前沿从 11920 顶到 11946，
  /// 让 11921~11943 这 23 首从「下次更新候选」里消失。
  final List<Song> earlyReleases;

  /// maidata 追加曲数（cids 全 0，既不是水鱼也不是 union，完全不参与对照）。
  final int maidataCount;

  /// union 全量曲数 = 水鱼 + union 独有（不含 maidata 追加）。
  int get unionSongCount =>
      cnSongCount + upcoming.length + skipped.length + utage.length;

  /// 本地曲库总条数 = union 全量 + maidata 追加。
  int get totalCount => unionSongCount + maidataCount;

  /// 有曲库数据（否则页面显示空态引导用户去刷新数据）。
  bool get hasData => totalCount > 0;

  /// 待上线按版本分组（按该版本里最小的 id 排序 = 大致按日服版本先后）。
  List<({String version, int count})> get upcomingByVersion {
    final firstIdOf = <String, int>{};
    final countOf = <String, int>{};
    for (final song in upcoming) {
      final version = song.basicInfo.from;
      final id = UnionUpdateCompareService.numericId(song.id);
      if (!countOf.containsKey(version)) {
        countOf[version] = 0;
        firstIdOf[version] = id;
      }
      countOf[version] = countOf[version]! + 1;
      if (id < firstIdOf[version]!) firstIdOf[version] = id;
    }
    final versions = countOf.keys.toList()
      ..sort((a, b) => firstIdOf[a]!.compareTo(firstIdOf[b]!));
    return [for (final v in versions) (version: v, count: countOf[v]!)];
  }
}

/// 国服更新对照的**纯逻辑**：输入本地曲库，输出 [UnionUpdateCompare]。
///
/// 刻意不碰 I/O 与缓存：数据来自 `MaimaiMusicDataManager.getCachedSongs()`
/// （已合并好的曲库），所以这里可以在单测里用构造出来的 [Song] 直接钉住口径。
class UnionUpdateCompareService {
  UnionUpdateCompareService._();

  /// 宴会场 id 的下界：6 位及以上视为宴会场（与项目里 `songId.length == 6` 一致）。
  static const int utageIdFloor = 100000;

  /// 直接算作「下次更新候选」的曲目 id（不看 id 前沿）。
  ///
  /// 为什么需要：候选段的判据是「union 独有 且 id 比国服前沿大」，但国服的更新
  /// 顺序并不严格按 id —— 这几首（11815~11821，日服 2025-07-11/12 的 PRiSM PLUS
  /// 批次）id 比当前前沿 11878 小，却会随下次更新补上。不特殊处理的话它们会掉进
  /// 「国服未收录旧曲」那段、被当成区域限定，正好从候选里消失。
  ///
  /// 只对 **union 独有**（水鱼没有）的曲目生效：哪天国服真上了，它们自然回到
  /// 「国服已上」，这一条不再有任何影响。
  /// 11819 目前两个源都没有，留在区间里只是为了保持 11815~11821 的可读性。
  ///
  /// 页面上**不做任何标记**：它们本来就是 id 最小的几首，候选段那句
  /// 「越靠前越可能先补上」已经解释了它们为什么排在最前面。
  static const Set<String> confirmedNextUpdateIds = {
    '11815',
    '11816',
    '11817',
    '11818',
    '11819',
    '11820',
    '11821',
  };

  /// 国服**超前上线**的曲目 id 白名单。
  ///
  /// 「超前上线」= 国服先于日服上线。它们的 id 排在国服曲目的最前面，但国服
  /// 按日服上线顺序实际还没追到那里 —— 拿它们算"国服最新曲"会把前沿顶高，
  /// 于是**真正待补的那批曲子被挡在候选之外**（实测：前沿 11920 → 被顶到 11946，
  /// 11921~11943 共 23 首从候选里消失，而那正是最可能先补上的一批）。
  ///
  /// ⚠️ 这是**需要人工维护的白名单**：国服以后再超前上线新曲时要往这里加。
  /// 试过自动推导，不可行：拿「水鱼版本 ≠ union版本」当判据会命中 378 首，
  /// 里面绝大多数只是前缀差异（`MiLK PLUS` vs `maimai MiLK PLUS`）或
  /// **国服滞后上线**（水鱼 PRiSM / union BUDDiES PLUS，方向正好相反）；
  /// 本地曲库也拿不到 union 的版本串（合并时只回填 release_date）。
  ///
  /// 11919 / 11920 是同一批（同一日服首发 2025-09-26、同一版本对
  /// 水鱼 PRiSM / union CiRCLE、id 相邻），两首都已确认并排除；
  /// 排除后前沿从 11919 落到 11878（Pixel Galaxy）。
  static const Set<String> cnEarlyReleaseIds = {
    '11919',
    '11920',
    '11944',
    '11945',
    '11946',
  };

  /// 取数值 id；解析不出来算 0（排序时排最前，不会污染"最新"判定）。
  static int numericId(String songId) => int.tryParse(songId) ?? 0;

  /// 本地曲库 → 更新对照。
  static UnionUpdateCompare compare(Iterable<Song> songs) {
    final unionOnly = <Song>[];
    final cnRegular = <Song>[];
    final earlyReleases = <Song>[];
    Song? frontier;
    var frontierId = -1;
    var cnSongCount = 0;
    var maidataCount = 0;

    for (final song in songs) {
      if (song.isExtra) {
        // union 独有 = 水鱼（国服）没有的曲子，先收集，等前沿算出来再分流。
        unionOnly.add(song);
        continue;
      }

      // maidata 追加的曲子（cids 全 0）：既不是水鱼也不是 union，不参与对照。
      if (SongFilterUtil.isMaidataSong(song.cids)) {
        maidataCount++;
        continue;
      }

      // 水鱼（国服）曲。
      cnSongCount++;
      if (SongFilterUtil.isUtageSong(song.id)) continue; // 宴会场不参与"最新"判定
      // 超前上线的曲目单独收：它们是国服已有的曲子，但不能当前沿
      // （否则真正待补的那批会被顶出候选，见 cnEarlyReleaseIds 的注释）。
      if (cnEarlyReleaseIds.contains(song.id)) {
        earlyReleases.add(song);
        continue;
      }
      cnRegular.add(song);
      final id = numericId(song.id);
      if (id > frontierId) {
        frontierId = id;
        frontier = song;
      }
    }

    final upcoming = <Song>[];
    final skipped = <Song>[];
    final utage = <Song>[];
    for (final song in unionOnly) {
      if (SongFilterUtil.isUtageSong(song.id)) {
        utage.add(song);
      } else if (confirmedNextUpdateIds.contains(song.id)) {
        // 名单内（见 confirmedNextUpdateIds）：直接算候选，
        // 不受"id 必须大于前沿"这条限制
        upcoming.add(song);
      } else if (numericId(song.id) > frontierId) {
        upcoming.add(song);
      } else {
        skipped.add(song);
      }
    }

    int byId(Song a, Song b) =>
        numericId(a.id).compareTo(numericId(b.id));
    upcoming.sort(byId);
    skipped.sort(byId);
    utage.sort(byId);
    // 国服已上的那批按 id 降序：第一首就是前沿，紧接着就是"待上线"的第一首
    cnRegular.sort((a, b) => byId(b, a));
    earlyReleases.sort(byId);

    return UnionUpdateCompare(
      frontier: frontier,
      upcoming: upcoming,
      skipped: skipped,
      utage: utage,
      cnSongs: cnRegular,
      earlyReleases: earlyReleases,
      cnSongCount: cnSongCount,
      cnRegularCount: cnRegular.length,
      maidataCount: maidataCount,
    );
  }
}
