import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/GameType.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({super.key});

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final MultiplayerManager _manager = MultiplayerManager();
  final GameType _gameType = GameType.info;
  int _maxPlayers = 4;
  int _timeLimit = 60;
  int _maxGuesses = 10;
  bool _isCreating = false;
  
  // 新增的设置参数（与 GuessChartByInfoPage 保持一致）
  List<String> _selectedVersions = [];
  double _masterMinDx = 1.0;
  double _masterMaxDx = 15.0;
  List<String> _selectedGenres = [];
  
  // 所有版本和流派列表
  List<String> _allVersions = [];
  List<String> _allGenres = [];
  bool _isLoading = true;

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
        
        for (var song in allSongs) {
          versions.add(song.basicInfo.from);
          genres.add(song.basicInfo.genre);
        }
        
        // 按照游戏发布顺序排序版本
        _allVersions = versions.toList()..sort((a, b) {
          final Map<String, int> versionOrder = {
            'maimai': 1,
            'maimai PLUS': 2,
            'maimai GreeN': 3,
            'maimai GreeN PLUS': 4,
            'maimai ORANGE': 5,
            'maimai ORANGE PLUS': 6,
            'maimai PiNK': 7,
            'maimai PiNK PLUS': 8,
            'maimai MURASAKi': 9,
            'maimai MURASAKi PLUS': 10,
            'maimai MiLK': 11,
            'MiLK PLUS': 12,
            'maimai FiNALE': 13,
            'maimai でらっくす': 14,
            'maimai でらっくす Splash': 15,
            'maimai でらっくす UNiVERSE': 16,
            'maimai でらっくす FESTiVAL': 17,
            'maimai でらっくす BUDDiES': 18,
            'maimai でらっくす PRiSM': 19,
          };
          int orderA = versionOrder[a] ?? 999;
          int orderB = versionOrder[b] ?? 999;
          return orderA.compareTo(orderB);
        });
        
        // 移除宴会场选项
        genres.remove('\u5bb4\u4f1a\u5834');
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
      // 检查是否有符合条件的乐曲
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

  @override
  Widget build(BuildContext context) {
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
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(paddingM, 48, paddingM, paddingS),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '创建房间',
                          style: TextStyle(
                            color: Color.fromARGB(255, 84, 97, 97),
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(paddingS, 0, paddingS, paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0 * scaleFactor,
                        offset: Offset(2.0 * scaleFactor, 2.0 * scaleFactor),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(paddingM),
                          child: Column(
                            children: [
                              // 游戏模式
                              Text(
                                '游戏模式',
                                style: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: paddingM),
                              Container(
                                padding: EdgeInsets.all(paddingM),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 84, 97, 97),
                                  borderRadius: BorderRadius.circular(borderRadiusSmall),
                                ),
                                child: Text(
                                  '无提示猜歌',
                                  style: TextStyle(color: Colors.white, fontSize: 18 * scaleFactor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(height: paddingL * 1.5),

                              // 房间基础设置
                              Text(
                                '房间设置',
                                style: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: paddingM),
                              Container(
                                padding: EdgeInsets.all(paddingM),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(borderRadiusSmall),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text('最大玩家数', style: TextStyle(fontSize: 14 * scaleFactor))),
                                        DropdownButton<int>(
                                          value: _maxPlayers,
                                          items: [2, 3, 4, 5, 6].map((value) {
                                            return DropdownMenuItem(
                                              value: value,
                                              child: Text('$value 人', style: TextStyle(fontSize: 14 * scaleFactor)),
                                            );
                                          }).toList(),
                                          onChanged: (value) => setState(() => _maxPlayers = value!),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: paddingM),
                                  ],
                                ),
                              ),
                              SizedBox(height: paddingL * 1.5),

                              // 歌曲筛选设置（与 GuessChartByInfoPage 保持一致）
                              Text(
                                '歌曲筛选设置',
                                style: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold),
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
                                  setState(() => _selectedVersions = versions);
                                },
                                (min, max) {
                                  setState(() {
                                    _masterMinDx = min;
                                    _masterMaxDx = max;
                                  });
                                },
                                (genres) {
                                  setState(() => _selectedGenres = genres);
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
                              SizedBox(height: paddingL * 1.5),

                              // 重置按钮
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
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
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[300],
                                    ),
                                    child: Text('重置所有设置', style: TextStyle(color: Colors.black)),
                                  ),
                                ),
                              ),
                              SizedBox(height: paddingL * 1.5),

                              // 创建按钮
                              ElevatedButton(
                                onPressed: _handleCreateRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                                  padding: EdgeInsets.symmetric(vertical: 16 * scaleFactor),
                                  minimumSize: Size(double.infinity, 50 * scaleFactor),
                                ),
                                child: _isCreating
                                    ? SizedBox(width: 24 * scaleFactor, height: 24 * scaleFactor, child: CircularProgressIndicator(color: Colors.white))
                                    : Text('创建房间', style: TextStyle(color: Colors.white, fontSize: 16 * scaleFactor)),
                              ),
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