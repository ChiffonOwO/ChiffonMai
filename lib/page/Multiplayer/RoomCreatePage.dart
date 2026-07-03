import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';
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

  // 所有版本和流派列表
  List<String> _allVersions = [];
  List<String> _allGenres = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadSongData();
  }

  Future<void> _loadSongData() async {
    setState(() => _isLoading = true);
    try {
      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (allSongs != null) {
        Set<String> versions = {};
        Set<String> genres = {};

        // 过滤掉从maidata追加的歌曲
        final validSongs = allSongs.where((song) =>
          song.cids.isNotEmpty && !song.cids.every((cid) => cid == 0)
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
           _gameType == GameType.letters;
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
                                  color: Theme.of(context).colorScheme.onSurface,
                                  borderRadius:
                                      BorderRadius.circular(borderRadiusSmall),
                                ),
                                child: DropdownButton<GameType>(
                                  value: _gameType,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  iconEnabledColor: Colors.white,
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
                                () {
                                  setState(() {
                                    _selectedVersions = [];
                                    _masterMinDx = 1.0;
                                    _masterMaxDx = 15.0;
                                    _selectedGenres = [];
                                    _maxGuesses = 10;
                                    _timeLimit = 60;
                                  });
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
                                      Theme.of(context).colorScheme.onSurface,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 16 * scaleFactor),
                                  minimumSize: Size(
                                      double.infinity, 50 * scaleFactor),
                                ),
                                child: _isCreating
                                    ? SizedBox(
                                        width: 24 * scaleFactor,
                                        height: 24 * scaleFactor,
                                        child: const CircularProgressIndicator(
                                            color: Colors.white),
                                      )
                                    : Text('创建房间',
                                        style: TextStyle(
                                            color: Colors.white,
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
