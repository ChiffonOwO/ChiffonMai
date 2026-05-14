import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/service/RankListService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';

class RankDetailPage extends StatefulWidget {
  final String rankName;

  const RankDetailPage({super.key, required this.rankName});

  @override
  State<RankDetailPage> createState() => _RankDetailPageState();
}

class _RankDetailPageState extends State<RankDetailPage> {
  final UserPlayDataManager _userPlayDataManager = UserPlayDataManager();
  final MaimaiMusicDataManager _musicDataManager = MaimaiMusicDataManager();
  
  Map<String, dynamic>? _userPlayData;
  List<Song>? _songs;
  bool _isLoading = true;

  late double _paddingXS;
  late double _paddingS;
  late double _paddingM;
  late double _paddingL;
  late double _borderRadiusSmall;
  late double _textSizeXS;
  late double _textSizeS;
  late double _textSizeM;
  late double _textSizeL;
  late double _scaleFactor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final playData = await _userPlayDataManager.getCachedUserPlayData();
      final songs = await _musicDataManager.getCachedSongs();
      
      setState(() {
        _userPlayData = playData;
        _songs = songs;
      });
    } catch (e) {
      print('加载数据时出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getAchievement(String songId, int difficulty) {
    if (_userPlayData == null) return '';
    
    final records = _userPlayData!['records'] as List?;
    if (records == null) return '';

    for (final record in records) {
      if (record is Map<String, dynamic>) {
        final recordSongId = record['song_id']?.toString();
        final recordDifficulty = record['level_index'] as int?;
        
        if (recordSongId == songId && recordDifficulty == difficulty) {
          return record['achievements']?.toString() ?? '';
        }
      }
    }
    
    return '';
  }

  Song? _getSongById(String songId) {
    if (_songs == null) return null;
    try {
      return _songs!.firstWhere((song) => song.id == songId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _scaleFactor = screenWidth / 375.0;
    _paddingXS = 4.0 * _scaleFactor;
    _paddingS = 8.0 * _scaleFactor;
    _paddingM = 12.0 * _scaleFactor;
    _paddingL = 16.0 * _scaleFactor;
    _borderRadiusSmall = 8.0 * _scaleFactor;
    _textSizeXS = 9.0 * _scaleFactor;
    _textSizeS = 11.0 * _scaleFactor;
    _textSizeM = 12.0 * _scaleFactor;
    _textSizeL = 14.0 * _scaleFactor;

    final rankData = RankListService().getRankData(widget.rankName);
    final isNormalRank = ['初段', '二段', '三段', '四段', '五段', '六段', '七段', '八段', '九段', '十段'].contains(widget.rankName);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(_paddingM, 48, _paddingM, _paddingS),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.rankName,
                          style: TextStyle(
                            color: Color.fromARGB(255, 84, 97, 97),
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(_paddingS, 0, _paddingS, _paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0 * _scaleFactor,
                        offset: Offset(2.0 * _scaleFactor, 2.0 * _scaleFactor),
                      ),
                    ],
                  ),
                  child: _isLoading 
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(_paddingM),
                        child: rankData != null ? _buildContent(rankData, isNormalRank) : _buildEmptyContent(),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(RankData rankData, bool isNormalRank) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingS),
          decoration: BoxDecoration(
            color: isNormalRank ? Color(0xFF8B4513) : Colors.purple,
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          child: Text(
            rankData.name,
            style: TextStyle(
              fontSize: _textSizeL,
              fontWeight: FontWeight.bold,
              color: isNormalRank ? Colors.white : Color(0xFFE6E6FA),
            ),
          ),
        ),
        
        SizedBox(height: _paddingM),
        
        Text(
          '段位曲目',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700]!,
          ),
        ),
        SizedBox(height: _paddingXS),
        Column(
          children: List.generate(4, (index) {
            final songId = rankData.songIds[index];
            final levelIndex = rankData.levelIndexes[index];
            final achievement = _getAchievement(songId, levelIndex);
            final song = _getSongById(songId);
            final hasAchievement = achievement.isNotEmpty;
            final achievementValue = double.tryParse(achievement) ?? 0.0;
            
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongInfoPage(
                      songId: songId,
                      initialLevelIndex: levelIndex,
                      isDefaultLevelIndex: false,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
              child: Container(
                margin: EdgeInsets.only(bottom: _paddingS),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _getDifficultyBorderColor(levelIndex),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                ),
                padding: EdgeInsets.all(_paddingS),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60 * _scaleFactor,
                      height: 60 * _scaleFactor,
                      child: Stack(
                        children: [
                          CoverUtil.buildCoverWidgetWithContext(
                            context,
                            songId.isNotEmpty ? songId : '0',
                            60 * _scaleFactor,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _getDifficultyBorderColor(levelIndex),
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: _paddingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song?.title ?? '曲目 ${index + 1}',
                            style: TextStyle(
                              fontSize: _textSizeM,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: _paddingXS, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getDifficultyBorderColor(levelIndex).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getDifficultyName(levelIndex),
                                  style: TextStyle(
                                    fontSize: _textSizeXS,
                                    color: _getDifficultyBorderColor(levelIndex),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: _paddingS),
                              Text(
                                hasAchievement ? '达成率: ${achievement}%' : '未游玩',
                                style: TextStyle(
                                  fontSize: _textSizeS,
                                  color: hasAchievement && achievementValue >= 100 ? Colors.green : Colors.grey[600]!,
                                  fontWeight: hasAchievement && achievementValue >= 100 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        SizedBox(height: _paddingM),
        
        Text(
          '血量设置',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700]!,
          ),
        ),
        SizedBox(height: _paddingXS),
        
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.0),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.all(_paddingM),
          child: Column(
            children: [
              Row(
                children: [
                  _buildStatCell('初始血量'),
                  _buildStatCell('GREAT'),
                  _buildStatCell('GOOD'),
                  _buildStatCell('MISS'),
                  _buildStatCell('通关回复'),
                ],
              ),
              SizedBox(height: _paddingXS),
              Row(
                children: [
                  _buildStatValueCell('${rankData.initialHp}', Colors.green),
                  _buildStatValueCell('-${rankData.greatDamage}', Colors.orange),
                  _buildStatValueCell('-${rankData.goodDamage}', Colors.red),
                  _buildStatValueCell('-${rankData.missDamage}', Colors.redAccent),
                  _buildStatValueCell('+${rankData.healAmount}', Colors.lightGreen),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCell(String label) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: _textSizeM),
      ),
    );
  }

  Widget _buildStatValueCell(String value, Color valueColor) {
    return Expanded(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _textSizeL,
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Center(
      child: Text(
        '未找到段位数据',
        style: TextStyle(
          fontSize: _textSizeM,
          color: Colors.grey[500]!,
        ),
      ),
    );
  }

  String _getDifficultyName(int levelIndex) {
    switch (levelIndex) {
      case 0: return 'BASIC';
      case 1: return 'ADVANCED';
      case 2: return 'EXPERT';
      case 3: return 'MASTER';
      case 4: return 'RE:MASTER';
      default: return 'UNKNOWN';
    }
  }

  Color _getDifficultyBorderColor(int levelIndex) {
    switch (levelIndex) {
      case 0: return Colors.green;
      case 1: return Color(0xFFFFCC00);
      case 2: return Colors.pink;
      case 3: return Colors.purple;
      case 4: return Colors.purple.shade200;
      default: return Colors.grey;
    }
  }
}