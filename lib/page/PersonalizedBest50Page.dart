import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import '../service/PersonalizedBest50Service.dart';
import '../manager/MaimaiMusicDataManager.dart';
import 'SongInfoPage.dart';
import '../utils/CoverUtil.dart';

class PersonalizedBest50Page extends StatefulWidget {
  const PersonalizedBest50Page({super.key});

  @override
  _PersonalizedBest50PageState createState() => _PersonalizedBest50PageState();
}

class _PersonalizedBest50PageState extends State<PersonalizedBest50Page> {
  List<Map<String, dynamic>> _personalizedSongs = [];
  bool _isLoading = true;
  String _selectedType = 'ap_plus_50'; // 默认选择AP+50
  String? _selectedCharter; // 选中的charter
  Map<String, int>? _charterCounts; // charter出现次数
  String? _selectedVersion; // 选中的版本
  Map<String, int>? _versionCounts; // 版本出现次数
  String? _selectedGenre; // 选中的流派
  Map<String, int>? _genreCounts; // 流派出现次数
  List<dynamic>? _maimaiMusicData;

  // 下拉选择的选项
  final List<Map<String, String>> _options = [
    {'value': 'ap_plus_50', 'label': 'AP+50'},
    {'value': 'ap_50', 'label': 'AP50'},
    {'value': 'fc_50', 'label': 'FC50'},
    {'value': 'fc_plus_50', 'label': 'FC+50'},
    {'value': 'fs_50', 'label': 'FS50'},
    {'value': 'fs_plus_50', 'label': 'FS+50'},
    {'value': 'fsd_50', 'label': 'FDX50'},
    {'value': 'fsdp_50', 'label': 'FDX+50'},
    {'value': 'cun_50', 'label': '寸50'},
    {'value': 'mingdao_50', 'label': '名刀50/锁血50'},
    {'value': 'cuniao_plus_50', 'label': '寸鸟加50'},
    {'value': 'suoxue_plus_50', 'label': '锁血鸟加50'},
    {'value': 'cuniao_50', 'label': '寸鸟50'},
    {'value': 'suoxue_50', 'label': '锁血鸟50'},
    {'value': 'charter_50', 'label': '谱师50'},
    {'value': 'genre_50', 'label': '流派50'},
    {'value': 'version_50', 'label': '版本50'},
    {'value': 'dx_50', 'label': 'DX50'},
    {'value': 'st_50', 'label': 'ST50'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPersonalizedData();
  }

  Future<void> _loadPersonalizedData() async {
    try {
      // 加载maimai音乐数据
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        if (songs != null) {
          setState(() {
            _maimaiMusicData = songs.map((song) => {
              'id': song.id,
              'title': song.title,
              'type': song.type,
              'ds': song.ds,
              'level': song.level,
              'cids': song.cids,
              'charts': song.charts.map((chart) => {
                'notes': chart.notes,
                'charter': chart.charter
              }).toList(),
              'basic_info': {
                'title': song.basicInfo.title,
                'artist': song.basicInfo.artist,
                'genre': song.basicInfo.genre,
                'bpm': song.basicInfo.bpm,
                'release_date': song.basicInfo.releaseDate,
                'from': song.basicInfo.from,
                'is_new': song.basicInfo.isNew
              }
            }).toList() as List<dynamic>;
          });
        }
      } else {
        // 如果API数据不存在，尝试从资产文件加载JSON数据作为 fallback
        final maimaiContents = await rootBundle.loadString('assets/maimai_music_data.json');
        final maimaiJsonData = json.decode(maimaiContents);

        setState(() {
          _maimaiMusicData = maimaiJsonData as List<dynamic>;
        });
      }

      // 加载charter出现次数、版本出现次数和流派出现次数
      final service = PersonalizedBest50Service();
      _charterCounts = await service.getCharterCounts();
      _versionCounts = await service.getVersionCounts();
      _genreCounts = await service.getGenreCounts();

      // 加载个性化数据
      await _fetchPersonalizedData();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPersonalizedData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = PersonalizedBest50Service();
      Map<String, dynamic>? data;

      // 根据选择的类型获取数据
      switch (_selectedType) {
        case 'ap_plus_50':
          data = await service.getAPPlus50Data();
          break;
        case 'ap_50':
          data = await service.getAP50Data();
          break;
        case 'fc_50':
          data = await service.getFC50Data();
          break;
        case 'fc_plus_50':
          data = await service.getFCPlus50Data();
          break;
        case 'cun_50':
          data = await service.getCun50Data();
          break;
        case 'mingdao_50':
          data = await service.getMingDao50Data();
          break;
        case 'charter_50':
          if (_selectedCharter != null) {
            data = await service.getCharter50Data(_selectedCharter!);
          }
          break;
        case 'version_50':
          if (_selectedVersion != null) {
            data = await service.getVersion50Data(_selectedVersion!);
          }
          break;
        case 'dx_50':
          data = await service.getDX50Data();
          break;
        case 'st_50':
          data = await service.getST50Data();
          break;
        case 'fs_50':
          data = await service.getFS50Data();
          break;
        case 'fs_plus_50':
          data = await service.getFSPlus50Data();
          break;
        case 'fsd_50':
          data = await service.getFDX50Data();
          break;
        case 'fsdp_50':
          data = await service.getFDXPlus50Data();
          break;
        case 'cuniao_plus_50':
          data = await service.getCuniaoPlus50Data();
          break;
        case 'suoxue_plus_50':
          data = await service.getSuoxuePlus50Data();
          break;
        case 'cuniao_50':
          data = await service.getCuniao50Data();
          break;
        case 'suoxue_50':
          data = await service.getSuoxue50Data();
          break;
        case 'genre_50':
          if (_selectedGenre != null) {
            data = await service.getGenre50Data(_selectedGenre!);
          }
          break;
      }

      if (data != null) {
        // 为记录添加歌曲信息
        final enrichedRecords = await service.enrichRecordsWithSongInfo((data['records'] is List ? data['records'] : []) as List<dynamic>);
        
        setState(() {
          _personalizedSongs = enrichedRecords;
          _isLoading = false;
        });
      } else {
        setState(() {
          _personalizedSongs = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching personalized data: $e');
      setState(() {
        _personalizedSongs = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 自定义常量
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.grey.withOpacity(0.5),
      spreadRadius: 2,
      blurRadius: 5,
      offset: Offset(0, 3),
    );

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
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '个性化Best50',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: MediaQuery.of(context).size.width * 0.06,
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
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 选择按钮
                        ElevatedButton(
                          onPressed: _showTypeSelectionDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: Text(
                            _selectedType == 'charter_50' && _selectedCharter != null
                                ? '选择类型: 谱师50 - ${_selectedCharter!}'
                                : _selectedType == 'version_50' && _selectedVersion != null
                                    ? '选择类型: 版本50 - ${StringUtil.formatVersion2(_selectedVersion!)}'
                                    : _selectedType == 'genre_50' && _selectedGenre != null
                                        ? '选择类型: 流派50 - ${_selectedGenre!}'
                                        : '选择类型: ${_options.firstWhere((option) => option['value'] == _selectedType)['label']!}',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width * 0.04,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.0),

                        // 数据统计区域
                        _buildStatsSection(),
                        SizedBox(height: 12.0),

                        // 歌曲列表
                        _buildSongList(),
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

  // 显示类型选择对话框
  void _showTypeSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择类型'),
          content: SingleChildScrollView(
            child: ListBody(
              children: _options.map((option) {
                return ListTile(
                  title: Text(option['label']!),
                  selected: _selectedType == option['value'],
                  onTap: () {
                    if (option['value'] == 'charter_50') {
                      // 显示charter选择对话框
                      Navigator.of(context).pop();
                      _showCharterSelectionDialog();
                    } else if (option['value'] == 'version_50') {
                      // 显示版本选择对话框
                      Navigator.of(context).pop();
                      _showVersionSelectionDialog();
                    } else if (option['value'] == 'genre_50') {
                      // 显示流派选择对话框
                      Navigator.of(context).pop();
                      _showGenreSelectionDialog();
                    } else {
                      setState(() {
                        _selectedType = option['value']!;
                        _selectedCharter = null;
                        _selectedVersion = null;
                        _selectedGenre = null;
                      });
                      Navigator.of(context).pop();
                      _fetchPersonalizedData();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 显示版本选择对话框
  void _showVersionSelectionDialog() {
    if (_versionCounts == null || _versionCounts!.isEmpty) {
      // 没有版本数据
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('没有找到版本数据'),
            actions: [
              TextButton(
                child: Text('确定'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 定义版本顺序
    final List<String> versionOrder = [
      'maimai',
      'maimai PLUS',
      'maimai GreeN',
      'maimai GreeN PLUS',
      'maimai ORANGE',
      'maimai ORANGE PLUS',
      'maimai PiNK',
      'maimai PiNK PLUS',
      'maimai MURASAKi',
      'maimai MURASAKi PLUS',
      'maimai MiLK',
      'MiLK PLUS',
      'maimai FiNALE',
      'maimai でらっくす',
      'maimai でらっくす Splash',
      'maimai でらっくす UNiVERSE',
      'maimai でらっくす FESTiVAL',
      'maimai でらっくす BUDDiES',
      'maimai でらっくす PRiSM',
    ];

    // 按版本顺序排序
    List<MapEntry<String, int>> sortedVersions = _versionCounts!.entries.toList()
      ..sort((a, b) {
        int indexA = versionOrder.indexOf(a.key);
        int indexB = versionOrder.indexOf(b.key);
        if (indexA != -1 && indexB != -1) {
          return indexA.compareTo(indexB);
        } else if (indexA != -1) {
          return -1;
        } else if (indexB != -1) {
          return 1;
        } else {
          // 如果都不在顺序列表中，按字符串排序
          return a.key.compareTo(b.key);
        }
      });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择版本'),
          content: SingleChildScrollView(
            child: ListBody(
              children: sortedVersions.map((entry) {
                return ListTile(
                  title: Text('${StringUtil.formatVersion2(entry.key)} (${entry.value}首)'),
                  selected: _selectedVersion == entry.key,
                  onTap: () {
                    setState(() {
                      _selectedType = 'version_50';
                      _selectedVersion = entry.key;
                    });
                    Navigator.of(context).pop();
                    _fetchPersonalizedData();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 显示流派选择对话框
  void _showGenreSelectionDialog() {
    if (_genreCounts == null || _genreCounts!.isEmpty) {
      // 没有流派数据
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('没有找到流派数据'),
            actions: [
              TextButton(
                child: Text('确定'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 按出现次数排序
    List<MapEntry<String, int>> sortedGenres = _genreCounts!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择流派'),
          content: SingleChildScrollView(
            child: ListBody(
              children: sortedGenres.map((entry) {
                return ListTile(
                  title: Text('${entry.key} (${entry.value}首)'),
                  selected: _selectedGenre == entry.key,
                  onTap: () {
                    setState(() {
                      _selectedType = 'genre_50';
                      _selectedGenre = entry.key;
                    });
                    Navigator.of(context).pop();
                    _fetchPersonalizedData();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 显示charter选择对话框
  void _showCharterSelectionDialog() {
    if (_charterCounts == null || _charterCounts!.isEmpty) {
      // 没有charter数据
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('没有找到符合条件的谱师数据'),
            actions: [
              TextButton(
                child: Text('确定'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 按出现次数排序
    List<MapEntry<String, int>> sortedCharters = _charterCounts!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择谱师'),
          content: SingleChildScrollView(
            child: ListBody(
              children: sortedCharters.map((entry) {
                return ListTile(
                  title: Text('${entry.key} (${entry.value}谱面)'),
                  selected: _selectedCharter == entry.key,
                  onTap: () {
                    setState(() {
                      _selectedType = 'charter_50';
                      _selectedCharter = entry.key;
                    });
                    Navigator.of(context).pop();
                    _fetchPersonalizedData();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 构建统计区域
  Widget _buildStatsSection() {
    // 计算各项指标
    int totalSongs = _personalizedSongs.length;
    int totalRa = _personalizedSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double averageRa = totalSongs > 0 ? totalRa / totalSongs : 0.0;

    double totalAchievement = _personalizedSongs.fold(0.0, (sum, song) {
      return sum + (double.tryParse(song['achievements'].toString()) ?? 0.0);
    });
    double averageAchievement = totalSongs > 0 ? totalAchievement / totalSongs : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Text(
              _selectedType == 'charter_50' && _selectedCharter != null
                  ? '谱师50 - ${_selectedCharter!} 统计'
                  : _selectedType == 'version_50' && _selectedVersion != null
                      ? '版本50 - ${StringUtil.formatVersion2(_selectedVersion!)} 统计'
                      : _selectedType == 'genre_50' && _selectedGenre != null
                          ? '流派50 - ${_selectedGenre!} 统计'
                          : '${_options.firstWhere((option) => option['value'] == _selectedType)['label']!} 统计',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.045,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '总谱面数',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '$totalSongs',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '总RA值',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '$totalRa',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '平均RA值',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '${averageRa.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '平均达成率',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '${averageAchievement.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建歌曲列表
  Widget _buildSongList() {
    if (_personalizedSongs.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _selectedType == 'charter_50' && _selectedCharter != null
                  ? '暂无谱师50 - ${_selectedCharter!} 数据'
                  : _selectedType == 'version_50' && _selectedVersion != null
                      ? '暂无版本50 - ${StringUtil.formatVersion2(_selectedVersion!)} 数据'
                      : _selectedType == 'genre_50' && _selectedGenre != null
                          ? '暂无流派50 - ${_selectedGenre!} 数据'
                          : '暂无${_options.firstWhere((option) => option['value'] == _selectedType)['label']!}数据',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '请返回首页点击"刷新数据"按钮获取',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        mainAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        childAspectRatio: 1.75,
      ),
      itemCount: _personalizedSongs.length,
      itemBuilder: (context, index) {
        return _buildDataGameCard(_personalizedSongs[index]);
      },
    );
  }

  // 根据数据构建游戏卡片
  Widget _buildDataGameCard(Map<String, dynamic> songData) {
    // 解析数据
    double achievementRate = double.tryParse(songData['achievements'].toString()) ?? 0.0;
    int score = songData['dxScore'] ?? 0;
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = songData['ds'] is double ? songData['ds'] : (double.tryParse(songData['ds'].toString()) ?? 0.0);
    String rate = songData['rate'] ?? '';
    int levelIndex = songData['level_index'] ?? 0;
    int rating = songData['ra'] ?? 0;
    String type = songData['type'] ?? '';
    String title = songData['title'] ?? '未知歌曲';
    int songId = songData['song_id'] ?? 0;

    // 计算星星等级
    double scoreRate = _calculateScoreRate(songId, levelIndex, score);
    String stars = StringUtil.formatStars(scoreRate);
    Color starsColor = ColorUtil.getStarsColor(stars);

    // 映射FC属性
    String fcText = fc.isNotEmpty ? StringUtil.formatFC(fc) : '-';

    // 映射FS属性
    String fsText = fs.isNotEmpty ? StringUtil.formatFS(fs) : '-';

    // 映射Rate属性
    String rateText = StringUtil.formatRate(rate);

    // 构建完整grade
    String grade = '$rateText | $fcText | $fsText';

    // 获取卡片颜色
      Color cardColor;
      // 对于6位数ID的歌曲，使用粉色
      if (songId.toString().length == 6) {
        cardColor = Color(0xFFFF99C2); // 进一步加深的粉色
      } else {
        cardColor = ColorUtil.getCardColor(levelIndex);
      }

    // 判断是否为DX模式或UT模式
      bool dxMode = type == 'DX';
      bool isUtage = songId.toString().length == 6; // 6位数ID为UTAGE

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: songId.toString(),
              initialLevelIndex: levelIndex,
              isDefaultLevelIndex: false, // 防止默认跳转到Master难度
            ),
          ),
        );
      },
      child: _buildGameCard(
        cardColor: cardColor,
        songName: title,
        achievementRate: achievementRate,
        difficulty: difficulty,
        dxMode: dxMode,
        isUtage: isUtage,
        score: score,
        rating: rating,
        stars: stars,
        grade: grade,
        songId: songId,
        starsColor: starsColor,
      ),
    );
  }

  // 构建游戏卡片
  Widget _buildGameCard({
    required Color cardColor,
    String songName = '未知歌曲',
    double achievementRate = 0.0,
    double difficulty = 0.0,
    bool dxMode = false,
    bool isUtage = false,
    int score = 0,
    int rating = 0,
    String stars = '',
    String grade = '',
    int? songId,
    Color starsColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = MediaQuery.of(context).size.width;

          // 根据宽度动态调整字体大小
          double songNameFontSize = screenWidth * 0.035;
          double decimalMainFontSize = screenWidth * 0.04;
          double decimalSmallFontSize = screenWidth * 0.03;
          double otherFontSize = screenWidth * 0.025;
          double gradeFontSize = screenWidth * 0.022;
          double dxFontSize = screenWidth * 0.025;

          double coverSize = screenWidth * 0.12;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 曲绘和难度
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 1.0),
                    ),
                    child: songId != null
                        ? CoverUtil.buildCoverWidgetWithContext(context, songId.toString(), coverSize)
                        : Center(
                            child: Text('曲绘',
                                style: TextStyle(fontSize: coverSize * 0.24)),
                          ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUtage)
                        Text(
                          'UT',
                          style: TextStyle(
                            fontSize: dxFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      if (dxMode && !isUtage)
                        Text(
                          'DX',
                          style: TextStyle(
                            fontSize: dxFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      if (!dxMode && !isUtage)
                        Text(
                          'ST',
                          style: TextStyle(
                            fontSize: dxFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade300,
                          ),
                        ),
                      SizedBox(width: screenWidth * 0.01),
                      // 难度显示
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            difficulty.toString().split('.')[0],
                            style: TextStyle(
                              fontSize: decimalMainFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (difficulty.toString().split('.').length > 1)
                            Text(
                              '.${difficulty.toString().split('.')[1]}',
                              style: TextStyle(
                                fontSize: decimalSmallFontSize * 0.9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: screenWidth * 0.02),

              // 右侧信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 歌曲名称
                    Text(
                      songName,
                      style: TextStyle(
                        fontSize: songNameFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: screenWidth * 0.007),

                    // 达成率
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          achievementRate.toStringAsFixed(4).split('.')[0],
                          style: TextStyle(
                            fontSize: decimalMainFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                          style: TextStyle(
                            fontSize: decimalSmallFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    // 评级、分数、星数
                    Row(
                      children: [
                        Text(
                          '$rating | $score | ',
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stars,
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: starsColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // 等级
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: gradeFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 计算scoreRate
  double _calculateScoreRate(int songId, int levelIndex, int score) {
    if (_maimaiMusicData == null) return 0.0;

    // 查找对应的歌曲
    int songIndex = _maimaiMusicData!.indexWhere(
      (item) => item['id'] == songId.toString(),
    );

    if (songIndex == -1) return 0.0;
    dynamic songData = _maimaiMusicData![songIndex];

    int maxScore = _calculateMaxDxScore(songData, levelIndex);

    // 计算scoreRate
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算最大DX分
  // 当ds数组长度为2时，返回两个难度谱面DX分之和
  // 否则返回当前难度的最大分数
  int _calculateMaxDxScore(dynamic songData, int levelIndex) {
    if (songData == null) return 0;

    // 检查ds数组长度
    List<dynamic> ds = songData['ds'];
    if (ds.length == 2) {
      // 计算两个难度谱面的最大分数之和
      int maxScore1 = _calculateMaxScore(songData, 0);
      int maxScore2 = _calculateMaxScore(songData, 1);
      return maxScore1 + maxScore2;
    } else {
      // 返回当前难度的最大分数
      return _calculateMaxScore(songData, levelIndex);
    }
  }

  // 计算单个难度的最大分数
  int _calculateMaxScore(dynamic songData, int levelIndex) {
    if (songData == null) return 0;

    if (songData['charts'] == null) return 0;

    // 查找对应的charts
    List<dynamic> charts = songData['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0;

    // 计算maxScore
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    return notesSum * 3;
  }
}