import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';
import 'package:my_first_flutter_app/constant/VersionListConstant.dart';

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({super.key});

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final MultiplayerManager _manager = MultiplayerManager();

  // 游戏类型
  GameType _gameType = GameType.info;

  // 房间基础设置
  int _maxPlayers = 4;
  int _timeLimit = 60;
  int _maxGuesses = 10;

  // 歌曲筛选设置
  List<String> _selectedVersions = [];
  double _masterMinDx = 1.0;
  double _masterMaxDx = 15.0;
  List<String> _selectedGenres = [];

  // 模式专属设置
  int _blurLevel = 50;            // 模糊程度 (blurred 模式)
  int _playDuration = 5;           // 音频播放时长秒 (audio 模式)
  int _songCount = 3;              // 抽取歌曲数 (letters 模式)
  int _nonEnglishCharThreshold = 50; // 非英文字符过滤阈值 (letters 模式)
  int _flashDurationMs = 300;      // 快闪时长毫秒 (flash 模式)
  int _tileCount = 1000;           // 拼图切块数 (tileReveal 模式)
  int _tileRevealIntervalMs = 1500; // 拼图揭示间隔毫秒 (tileReveal 模式)
  int _peekDurationSeconds = 8;    // 谱面片段时长秒 (chartPeek 模式)
  List<String> _peekDifficulties = ['4']; // 谱面难度随机池 (chartPeek 模式)

  /// chartPeek 难度池可选值（inote 编号 → 显示名，与单人谱面片段猜歌一致：
  /// BASIC 是 '2'，没有 '1'）
  static const Map<String, String> _difficultyLabels = {
    '2': 'BASIC',
    '3': 'ADVANCED',
    '4': 'EXPERT',
    '5': 'MASTER',
    '6': 'Re:MASTER',
  };

  // 所有版本和流派列表
  List<String> _allVersions = [];
  List<String> _allGenres = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadModeDefaults();
    _loadSongData();
  }

  /// 模式专属滑条的初始值取「已保存的单人猜歌设置」。
  ///
  /// 为什么要有这一步：单人「曲绘拼图/快闪/谱面片段」的设置和多人房间的参数
  /// 是两套（房间参数随房间走、由房主决定），但如果房间滑条永远从硬编码默认值
  /// 起步，用户刚在单人设置里把拼图调成 2500 块、进房间却看到 1000，
  /// 看起来就像「设置没生效/没同步」。这里只把它当**初值**，
  /// 房间真正的取值仍以房主在本页的设定为准（不会回写单人设置）。
  Future<void> _loadModeDefaults() async {
    try {
      final settings = await GuessChartCommonSettingsService().loadSettings();
      if (!mounted) return;
      setState(() {
        _blurLevel = settings['blurLevel'] ?? _blurLevel;
        _playDuration = settings['playDurationSeconds'] ?? _playDuration;
        _songCount = settings['songCount'] ?? _songCount;
        _nonEnglishCharThreshold =
            settings['nonEnglishCharThreshold'] ?? _nonEnglishCharThreshold;
        _flashDurationMs = settings['flashDurationMs'] ?? _flashDurationMs;
        _tileCount = settings['tileCount'] ?? _tileCount;
        _tileRevealIntervalMs =
            settings['tileRevealIntervalMs'] ?? _tileRevealIntervalMs;
        _peekDurationSeconds =
            settings['peekDurationSeconds'] ?? _peekDurationSeconds;
        final pool = (settings['peekDifficulties'] as List?)?.cast<String>();
        if (pool != null && pool.isNotEmpty) {
          _peekDifficulties = List<String>.from(pool);
        }
      });
      debugPrint('[DEBUG][RoomCreatePage] 模式专属默认值已从单人设置载入: '
          'tileCount=$_tileCount, tileRevealIntervalMs=$_tileRevealIntervalMs, '
          'flashDurationMs=$_flashDurationMs, peekDurationSeconds=$_peekDurationSeconds');
    } catch (e) {
      debugPrint('[DEBUG][RoomCreatePage] 读取单人设置失败（沿用默认值）: $e');
    }
  }

  Future<void> _loadSongData() async {
    setState(() => _isLoading = true);
    try {
      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (allSongs != null) {
        Set<String> versions = {};
        Set<String> genres = {};

        // 过滤掉从maidata追加的歌曲和union独有的歌曲
        final validSongs = allSongs.where((song) =>
          song.cids.isNotEmpty && !song.cids.every((cid) => cid == 0) && !song.isExtra
        ).toList();

        for (var song in validSongs) {
          versions.add(song.basicInfo.from);
          genres.add(song.basicInfo.genre);
        }

        // 过滤只保留标准版本
        versions = versions.where((v) => VersionListConstant.standardVersions.contains(v)).toSet();

        // 按发布顺序排序版本
        _allVersions = versions.toList()..sort((a, b) {
          int orderA = VersionListConstant.versionOrderMap[a] ?? 999;
          int orderB = VersionListConstant.versionOrderMap[b] ?? 999;
          return orderA.compareTo(orderB);
        });

        // 移除宴会场选项
        genres.remove('宴会场');
        _allGenres = genres.toList();
      }
    } catch (e) {
      debugPrint('[ERROR][RoomCreatePage] 加载歌曲数据失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateRoom() async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      // 根据游戏类型检查是否有符合条件的歌曲
      final testSong = await GuessChartByInfoService.randomSelectSong(
        selectedVersions: _selectedVersions,
        masterMinDx: _masterMinDx,
        masterMaxDx: _masterMaxDx,
        selectedGenres: _selectedGenres,
      );

      if (testSong == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有找到符合条件的乐曲！请检查设置！')),
        );
        setState(() => _isCreating = false);
        return;
      }

      debugPrint('[DEBUG][RoomCreatePage] 创建房间 - 选择的游戏模式: ${_gameType.name} (${_gameType.description})');

      final room = await _manager.createRoom(
        gameType: _gameType,
        maxPlayers: _maxPlayers,
        timeLimit: _timeLimit,
        maxGuesses: _maxGuesses,
        selectedVersions: _selectedVersions,
        masterMinDx: _masterMinDx,
        masterMaxDx: _masterMaxDx,
        selectedGenres: _selectedGenres,
        blurLevel: _blurLevel,
        playDuration: _playDuration,
        songCount: _songCount,
        nonEnglishCharThreshold: _nonEnglishCharThreshold,
        flashDurationMs: _flashDurationMs,
        tileCount: _tileCount,
        tileRevealIntervalMs: _tileRevealIntervalMs,
        peekDurationSeconds: _peekDurationSeconds,
        peekDifficulties: _peekDifficulties,
      );

      if (room != null) {
        Navigator.pop(context, room);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建房间失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建房间失败: $e')),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  /// 当前游戏模式是否需要模式专属设置
  bool get _needsModeSettings {
    return _gameType == GameType.blurred ||
           _gameType == GameType.audio ||
           _gameType == GameType.letters ||
           _gameType == GameType.flash ||
           _gameType == GameType.tileReveal ||
           _gameType == GameType.chartPeek;
  }

  /// 构建模式专属设置区域
  Widget _buildModeSpecificSettings(double scaleFactor, Brightness brightness) {
    if (!_needsModeSettings) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16 * scaleFactor),
        Text(
          '模式专属设置',
          style: TextStyle(
            fontSize: 16 * scaleFactor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12 * scaleFactor),
        Container(
          padding: EdgeInsets.all(12 * scaleFactor),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8 * scaleFactor),
          ),
          child: Column(
            children: [
              // 模糊程度 (模糊曲绘模式)
              if (_gameType == GameType.blurred)
                _buildSliderSetting(
                  label: '模糊程度',
                  value: _blurLevel.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  suffix: '%',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) => setState(() => _blurLevel = v.toInt()),
                ),
              // 播放时长 (音频片段模式)
              if (_gameType == GameType.audio)
                _buildSliderSetting(
                  label: '播放时长',
                  value: _playDuration.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  suffix: ' 秒',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) => setState(() => _playDuration = v.toInt()),
                ),
              // 歌曲数量 (开字母模式)
              if (_gameType == GameType.letters) ...[
                _buildSliderSetting(
                  label: '每次抽取歌曲数',
                  value: _songCount.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  suffix: ' 首',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) => setState(() => _songCount = v.toInt()),
                ),
                SizedBox(height: 12 * scaleFactor),
                _buildSliderSetting(
                  label: '非英文字符过滤阈值',
                  value: _nonEnglishCharThreshold.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  suffix: '%',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) => setState(() => _nonEnglishCharThreshold = v.toInt()),
                ),
              ],
              // 快闪时长 (曲绘快闪模式)
              if (_gameType == GameType.flash)
                _buildSliderSetting(
                  label: '快闪时长',
                  value: _flashDurationMs.toDouble(),
                  min: 100,
                  max: 3000,
                  divisions: 29, // 100ms 步进
                  suffix: ' ms',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) =>
                      setState(() => _flashDurationMs = (v / 100).round() * 100),
                ),
              // 切块数与揭示间隔 (曲绘拼图模式)
              if (_gameType == GameType.tileReveal) ...[
                _buildSliderSetting(
                  label: '切块数量',
                  value: _tileCount.toDouble(),
                  min: 100,
                  max: 10000,
                  divisions: 99,
                  suffix: ' 块',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) => setState(() => _tileCount = v.toInt()),
                ),
                SizedBox(height: 12 * scaleFactor),
                _buildSliderSetting(
                  label: '揭示间隔',
                  value: _tileRevealIntervalMs.toDouble(),
                  min: 100,
                  max: 10000,
                  divisions: 99,
                  suffix: ' ms',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) => setState(
                      () => _tileRevealIntervalMs = (v / 100).round() * 100),
                ),
              ],
              // 片段时长与难度池 (谱面片段模式)
              if (_gameType == GameType.chartPeek) ...[
                _buildSliderSetting(
                  label: '片段时长',
                  value: _peekDurationSeconds.toDouble(),
                  min: 3,
                  max: 60,
                  divisions: 57,
                  suffix: ' 秒',
                  scaleFactor: scaleFactor,
                  brightness: brightness,
                  onChanged: (v) =>
                      setState(() => _peekDurationSeconds = v.toInt()),
                ),
                SizedBox(height: 12 * scaleFactor),
                _buildDifficultyPoolSetting(scaleFactor, brightness),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required double scaleFactor,
    required Brightness brightness,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14 * scaleFactor)),
            Text(
              '${value.toInt()}$suffix',
              style: TextStyle(
                fontSize: 14 * scaleFactor,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toInt()}$suffix',
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 谱面难度随机池（chartPeek 模式）：勾选『难度池』，至少保留一个。
  ///
  /// 与单人谱面片段猜歌同一套口径：池内每个难度各自的定数落在房间的
  /// MASTER 定数范围内即可入选，抽谱时从池内随机挑一个难度播放。
  Widget _buildDifficultyPoolSetting(double scaleFactor, Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('难度随机池', style: TextStyle(fontSize: 14 * scaleFactor)),
        SizedBox(height: 8 * scaleFactor),
        Wrap(
          spacing: 8 * scaleFactor,
          runSpacing: 4 * scaleFactor,
          children: _difficultyLabels.entries.map((entry) {
            final String inote = entry.key;
            final bool selected = _peekDifficulties.contains(inote);
            return FilterChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    if (!_peekDifficulties.contains(inote)) {
                      _peekDifficulties.add(inote);
                    }
                  } else {
                    _peekDifficulties.remove(inote);
                    // 至少保留一个难度，否则抽谱时没有可播的谱面
                    if (_peekDifficulties.isEmpty) {
                      _peekDifficulties.add('4');
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0;
    final paddingS = 8.0 * scaleFactor;
    final paddingM = 12.0 * scaleFactor;
    final paddingL = 16.0 * scaleFactor;
    final borderRadiusSmall = 8.0 * scaleFactor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(paddingM, 48, paddingM, paddingS),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '创建房间',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin:
                      EdgeInsets.fromLTRB(paddingS, 0, paddingS, paddingL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppConstants.defaultShadow(brightness)],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(paddingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ======== 游戏模式选择 ========
                              Text(
                                '游戏模式',
                                style: TextStyle(
                                  fontSize: 16 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: paddingM),
                              // 模式选择下拉框
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: paddingM, vertical: paddingS),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius:
                                      BorderRadius.circular(borderRadiusSmall),
                                ),
                                child: DropdownButton<GameType>(
                                  value: _gameType,
                                  isExpanded: true,
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  iconEnabledColor: Theme.of(context).colorScheme.onPrimary,
                                  underline: const SizedBox(),
                                  items: GameType.values.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type.name,
                                        style: TextStyle(
                                          fontSize: 16 * scaleFactor,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  selectedItemBuilder: (context) {
                                    return GameType.values.map((type) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          type.name,
                                          style: TextStyle(
                                            fontSize: 18 * scaleFactor,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  },
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _gameType = value);
                                    }
                                  },
                                ),
                              ),
                              // 模式描述
                              Padding(
                                padding:
                                    EdgeInsets.only(top: paddingS, left: 4),
                                child: Text(
                                  _gameType.description,
                                  style: TextStyle(
                                    fontSize: 13 * scaleFactor,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              SizedBox(height: paddingL * 1.2),

                              // ======== 歌曲筛选设置 ========
                              Text(
                                '歌曲筛选设置',
                                style: TextStyle(
                                  fontSize: 16 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: paddingM),
                              CommonWidgetUtil.buildGuessChartSettingsWidget(
                                context,
                                _allVersions,
                                _allGenres,
                                _selectedVersions,
                                _masterMinDx,
                                _masterMaxDx,
                                _selectedGenres,
                                _maxGuesses,
                                _timeLimit,
                                (versions) {
                                  setState(
                                      () => _selectedVersions = versions);
                                },
                                (min, max) {
                                  setState(() {
                                    _masterMinDx = min;
                                    _masterMaxDx = max;
                                  });
                                },
                                (genres) {
                                  setState(
                                      () => _selectedGenres = genres);
                                },
                                (guesses) {
                                  setState(() => _maxGuesses = guesses);
                                },
                                (time) {
                                  setState(() => _timeLimit = time);
                                },
                              ),

                              // ======== 房间基础设置 ========
                              SizedBox(height: paddingL * 1.2),
                              Text(
                                '房间设置',
                                style: TextStyle(
                                  fontSize: 16 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: paddingM),
                              Container(
                                padding: EdgeInsets.all(paddingM),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius.circular(borderRadiusSmall),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text('最大玩家数',
                                            style: TextStyle(
                                                fontSize:
                                                    14 * scaleFactor))),
                                    DropdownButton<int>(
                                      value: _maxPlayers,
                                      items: [2, 3, 4, 5, 6].map((value) {
                                        return DropdownMenuItem(
                                          value: value,
                                          child: Text('$value 人',
                                              style: TextStyle(
                                                  fontSize:
                                                      14 * scaleFactor)),
                                        );
                                      }).toList(),
                                      onChanged: (value) =>
                                          setState(() => _maxPlayers = value!),
                                    ),
                                  ],
                                ),
                              ),

                              // ======== 模式专属设置 ========
                              _buildModeSpecificSettings(scaleFactor, brightness),

                              // ======== 重置按钮 ========
                              SizedBox(height: paddingL * 1.2),
                              Center(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedVersions = [];
                                      _masterMinDx = 1.0;
                                      _masterMaxDx = 15.0;
                                      _selectedGenres = [];
                                      _maxGuesses = 10;
                                      _timeLimit = 60;
                                      _maxPlayers = 4;
                                      _blurLevel = 50;
                                      _playDuration = 5;
                                      _songCount = 3;
                                      _nonEnglishCharThreshold = 50;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Text('重置所有设置',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                ),
                              ),

                              // ======== 创建按钮 ========
                              SizedBox(height: paddingL),
                              ElevatedButton(
                                onPressed: _isCreating ? null : _handleCreateRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 16 * scaleFactor),
                                  minimumSize: Size(
                                      double.infinity, 50 * scaleFactor),
                                ),
                                child: _isCreating
                                    ? SizedBox(
                                        width: 24 * scaleFactor,
                                        height: 24 * scaleFactor,
                                        child: CircularProgressIndicator(
                                            color: Theme.of(context).colorScheme.onPrimary),
                                      )
                                    : Text('创建房间',
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontSize: 16 * scaleFactor)),
                              ),
                              SizedBox(height: paddingL),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
