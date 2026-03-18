import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartByInfoService.dart';

class GuessChartByInfoPage extends StatefulWidget {
  const GuessChartByInfoPage({super.key});

  @override
  State<GuessChartByInfoPage> createState() => _GuessChartByInfoPageState();
}

class _GuessChartByInfoPageState extends State<GuessChartByInfoPage> {
  // 游戏状态
  bool _isGameStarted = false;
  Song? _targetSong;
  GuessSong? _targetGuessSong;
  List<GuessSong> _guessHistory = [];
  int _guessCount = 0;
  static const int _maxGuesses = 10;
  bool _isGameOver = false;
  bool _isWon = false;

  // 搜索状态
  TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;

  // 歌曲别名管理器
  late SongAliasManager _songAliasManager;

  @override
  void initState() {
    super.initState();
    _songAliasManager = SongAliasManager.instance;
    _initGame();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // 初始化游戏
  Future<void> _initGame() async {
    await _songAliasManager.init();
    await _startNewGame();
  }

  // 开始新游戏
  Future<void> _startNewGame() async {
    setState(() {
      _isGameStarted = false;
      _isGameOver = false;
      _isWon = false;
      _guessHistory = [];
      _guessCount = 0;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    // 随机选择目标歌曲
    _targetSong = await GuessChartByInfoService.randomSelectSong();
    if (_targetSong != null) {
      _targetGuessSong = await GuessChartByInfoService.buildGuessSongEntity(_targetSong!);
      setState(() {
        _isGameStarted = true;
      });
    }
  }

  // 处理搜索输入
  void _handleSearchInput(String value) {
    // 取消之前的定时器
    _searchTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    // 设置新的定时器
    _searchTimer = Timer(_searchDelay, () async {
      if (value.isEmpty) return;

      setState(() {
        _isSearching = true;
      });

      // 加载所有歌曲
      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (allSongs != null) {
        // 搜索歌曲（支持原曲名和别名）
        final results = await _searchSongs(allSongs, value);
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  // 搜索歌曲（支持原曲名和别名）
  Future<List<Song>> _searchSongs(List<Song> songs, String query) async {
    List<Song> results = [];
    query = query.toLowerCase();

    // 搜索原曲名
    results.addAll(songs.where((song) =>
        song.basicInfo.title.toLowerCase().contains(query)));

    // 搜索别名
    for (var song in songs) {
      if (!results.contains(song)) {
        // 检查别名
        final songId = song.id;
        final aliases = _songAliasManager.aliases[songId];
        if (aliases != null && aliases.any((alias) => alias.toLowerCase().contains(query))) {
          results.add(song);
        }
      }
    }

    // 限制结果数量
    return results.take(20).toList();
  }

  // 处理猜测
  Future<void> _handleGuess(Song guessedSong) async {
    if (_isGameOver) return;

    // 构建猜测实体
    var guessSong = await GuessChartByInfoService.buildGuessSongEntity(guessedSong);
    // 计算猜测结果
    guessSong = await GuessChartByInfoService.calculateGuessResult(guessSong, _targetSong!);

    // 更新猜测历史
    setState(() {
      _guessHistory.add(guessSong);
      _guessCount++;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    // 检查游戏是否结束
    if (guessedSong.basicInfo.title == _targetSong!.basicInfo.title) {
      setState(() {
        _isGameOver = true;
        _isWon = true;
      });
    } else if (_guessCount >= _maxGuesses) {
      setState(() {
        _isGameOver = true;
        _isWon = false;
      });
    }
  }

  // 构建搜索结果项
  Widget _buildSearchResultItem(Song song) {
    return GestureDetector(
      onTap: () {
        _handleGuess(song);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song.basicInfo.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              song.basicInfo.artist,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // 构建猜测历史项
  Widget _buildGuessHistoryItem(GuessSong guessSong, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '猜测 #${index + 1}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // 歌曲信息网格
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              _buildInfoItem('曲名', guessSong.title, guessSong.titleBgColor ?? Colors.grey),
              _buildInfoItem('类型', guessSong.type, guessSong.typeBgColor ?? Colors.grey),
              _buildInfoItem('BPM', guessSong.bpm.toString(), guessSong.bpmBgColor ?? Colors.grey),
              _buildInfoItem('曲师', guessSong.artist, guessSong.artistBgColor ?? Colors.grey),
              _buildInfoItem('Master', guessSong.masterLevel, guessSong.masterLevelBgColor ?? Colors.grey),
              _buildInfoItem('谱师', guessSong.masterCharter, guessSong.masterCharterBgColor ?? Colors.grey),
              if (guessSong.remasterLevel.isNotEmpty)
                _buildInfoItem('Re:Master', guessSong.remasterLevel, guessSong.remasterLevelBgColor ?? Colors.grey),
              if (guessSong.remasterCharter.isNotEmpty)
                _buildInfoItem('谱师', guessSong.remasterCharter, guessSong.remasterCharterBgColor ?? Colors.grey),
              _buildInfoItem(' genre', guessSong.genre, guessSong.genreBgColor ?? Colors.grey),
              _buildInfoItem('版本', guessSong.version, guessSong.versionBgColor ?? Colors.grey),
            ],
          ),
          // 标签
          if (guessSong.masterTags.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  '标签',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(guessSong.masterTags.length, (i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: guessSong.tagBgColors?[i] ?? Colors.grey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        guessSong.masterTags[i],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 构建信息项
  Widget _buildInfoItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('猜歌游戏'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewGame,
          ),
        ],
      ),
      body: _isGameStarted
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 游戏状态
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '猜测次数: $_guessCount/$_maxGuesses',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (_isGameOver)
                          Text(
                            _isWon ? '恭喜你猜对了！' : '游戏结束，你没有猜对',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isWon ? Colors.green : Colors.red,
                            ),
                          ),
                        if (_isGameOver && !_isWon)
                          Text(
                            '正确答案: ${_targetSong?.basicInfo.title}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 搜索输入框
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _handleSearchInput,
                      enabled: !_isGameOver,
                      decoration: const InputDecoration(
                        hintText: '输入歌曲名称或别名',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),

                  // 搜索结果
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        color: Colors.white,
                      ),
                      constraints: BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultItem(_searchResults[index]);
                        },
                      ),
                    ),

                  // 搜索中状态
                  if (_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 猜测历史
                  if (_guessHistory.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '猜测历史',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._guessHistory.asMap().entries.map((entry) {
                          return _buildGuessHistoryItem(entry.value, entry.key);
                        }),
                      ],
                    ),

                  // 游戏结束提示
                  if (_isGameOver)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: ElevatedButton(
                        onPressed: _startNewGame,
                        child: const Text('开始新游戏'),
                      ),
                    ),
                ],
              ),
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}