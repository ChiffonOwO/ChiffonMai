import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/service/RankTable/RankTableService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/manager/DivingFish/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
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
      debugPrint('加载数据时出错: $e');
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

  int _parseAchievementToInt(String achievement) {
    if (achievement.isEmpty) return 0;
    String cleaned = achievement.replaceAll('%', '');
    double value = double.tryParse(cleaned) ?? 0.0;
    return (value * 10000).round();
  }

  int _calcMinDamage(Song song, int levelIndex, String achievement, RankData rankData) {
    if (achievement.isEmpty) return 0;
    if (levelIndex < 0 || levelIndex >= song.charts.length) return 0;
    
    final chart = song.charts[levelIndex];
    final notes = chart.notes;
    if (notes.isEmpty) return 0;
    
    // notes数组: DX=[tap, hold, slide, touch, break], SD=[tap, hold, slide, break]
    final tap = notes[0];
    final hold = notes.length >= 2 ? notes[1] : 0;
    final slide = notes.length >= 3 ? notes[2] : 0;
    final touch = notes.length >= 5 ? notes[3] : 0;
    final breakNote = notes.length >= 5 ? notes[4] : (notes.length >= 4 ? notes[3] : 0);
    
    final totalBase = tap + touch + 2 * hold + 3 * slide + 5 * breakNote;
    if (totalBase == 0) return 0;
    
    final base = 100000.0 / totalBase;
    final achievementInt = _parseAchievementToInt(achievement);
    if (achievementInt <= 0) return 0;
    
    final minus = 1010000 - achievementInt;
    final amount = minus / base;
    
    final greats = (amount / 2).floor();
    final goods = (amount / 5).floor();
    final misses = (amount / 10).floor();
    
    final damages = <int>[];
    if (rankData.greatDamage != 0) {
      damages.add(rankData.greatDamage * greats);
    }
    if (rankData.goodDamage != 0) {
      damages.add(rankData.goodDamage * goods);
    }
    if (rankData.missDamage != 0) {
      damages.add(rankData.missDamage * misses);
    }
    
    if (damages.isEmpty) return 0;
    damages.sort();
    return damages.first;
  }

  // 计算剩余血量和总达成率
  Map<String, dynamic> _calcResult(RankData rankData) {
    double totalAchievement = 0;
    int remainingHp = rankData.initialHp;
    bool isDead = false;
    
    for (int i = 0; i < 4; i++) {
      final songId = rankData.songIds[i];
      final levelIndex = rankData.levelIndexes[i];
      final achievement = _getAchievement(songId, levelIndex);
      final achievementValue = double.tryParse(achievement) ?? 0.0;
      totalAchievement += achievementValue;
      
      if (!isDead && achievement.isNotEmpty) {
        final song = _getSongById(songId);
        if (song != null) {
          final damage = _calcMinDamage(song, levelIndex, achievement, rankData);
          remainingHp -= damage;
          if (remainingHp <= 0) {
            remainingHp = 0;
            isDead = true;
          } else if (i < 3) {
            // 前3首通关后回复（不超过初始血量上限）
            remainingHp = (remainingHp + rankData.healAmount).clamp(0, rankData.initialHp);
          }
          // 最后一首（i==3）不回复，直接以扣血后的血量作为最终结果
        }
      }
    }
    
    return {
      'totalAchievement': totalAchievement,
      'remainingHp': remainingHp,
      'isDead': isDead,
    };
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
    final brightness = Theme.of(context).brightness;
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
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final cardBgColor = Theme.of(context).colorScheme.surface;
    final cardShadow = AppColors.defaultShadow(brightness);

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
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.rankName,
                          style: TextStyle(
                            color: textPrimaryColor,
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
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    boxShadow: [cardShadow],
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
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingS),
          decoration: BoxDecoration(
            color: isNormalRank ? AppColors.medalColor('bronze') : Colors.purple,
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          child: Text(
            rankData.name,
            style: TextStyle(
              fontSize: _textSizeL,
              fontWeight: FontWeight.bold,
              color: isNormalRank ? Colors.white : const Color(0xFFE6E6FA),
            ),
          ),
        ),
        
        SizedBox(height: _paddingM),
        
        Text(
          '段位曲目',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: subtitleColor,
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
                          Row(
                            children: [
                              _buildSongTypeTag(song?.type),
                              SizedBox(width: _paddingXS),
                              Expanded(
                                child: Text(
                                  song?.title ?? '曲目 ${index + 1}',
                                  style: TextStyle(
                                    fontSize: _textSizeM,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                                hasAchievement ? '达成率: ${achievementValue.toStringAsFixed(4)}%' : '未游玩',
                                style: TextStyle(
                                  fontSize: _textSizeS,
                                  color: hasAchievement && achievementValue >= 100 ? AppColors.successGreen(brightness) : subtitleColor,
                                  fontWeight: hasAchievement && achievementValue >= 100 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          if (hasAchievement && song != null) ...[
                            SizedBox(height: 2),
                            Builder(
                              builder: (context) {
                                final minDamage = _calcMinDamage(song, levelIndex, achievement, rankData);
                                return Text(
                                  '预计最低扣血: $minDamage',
                                  style: TextStyle(
                                    fontSize: _textSizeS,
                                    color: minDamage > 0 ? AppColors.errorRed(brightness) : AppColors.greyHint(brightness),
                                    fontWeight: minDamage > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        () {
          final result = _calcResult(rankData);
          final totalAchievement = result['totalAchievement'] as double;
          final remainingHp = result['remainingHp'] as int;
          final isDead = result['isDead'] as bool;
          
          bool allHaveAchievement = true;
          for (int i = 0; i < 4; i++) {
            final a = _getAchievement(rankData.songIds[i], rankData.levelIndexes[i]);
            if (a.isEmpty) {
              allHaveAchievement = false;
              break;
            }
          }
          
          if (!allHaveAchievement) return SizedBox.shrink();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: _paddingM),
              Text(
                '预计结果',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
              SizedBox(height: _paddingXS),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.tableBorder(brightness), width: 1.0),
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                ),
                padding: EdgeInsets.all(_paddingM),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCell('总达成率'),
                        _buildStatCell('剩余血量'),
                        _buildStatCell('结果'),
                      ],
                    ),
                    SizedBox(height: _paddingXS),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${totalAchievement.toStringAsFixed(4)}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _textSizeL,
                              fontWeight: FontWeight.bold,
                              color: totalAchievement >= 400 ? AppColors.successGreen(brightness) : AppColors.errorRed(brightness),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            remainingHp.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _textSizeL,
                              fontWeight: FontWeight.bold,
                              color: remainingHp > 0 ? AppColors.successGreen(brightness) : AppColors.errorRed(brightness),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            isDead ? '不合格' : '合格',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _textSizeL,
                              fontWeight: FontWeight.bold,
                              color: isDead ? AppColors.errorRed(brightness) : AppColors.successGreen(brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }(),
        
        SizedBox(height: _paddingM),
        
        Text(
          '血量设置',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: subtitleColor,
          ),
        ),
        SizedBox(height: _paddingXS),
        
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.tableBorder(brightness), width: 1.0),
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
                  _buildStatValueCell('${rankData.initialHp}', AppColors.successGreen(brightness)),
                  _buildStatValueCell('-${rankData.greatDamage}', AppColors.warningOrange(brightness)),
                  _buildStatValueCell('-${rankData.goodDamage}', AppColors.errorRed(brightness)),
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
    final brightness = Theme.of(context).brightness;
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: _textSizeM, color: Theme.of(context).colorScheme.onSurface),
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
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Text(
        '未找到段位数据',
        style: TextStyle(
          fontSize: _textSizeM,
          color: AppColors.greyHint(brightness),
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
    return AppColors.difficultyForegroundByIndex(levelIndex);
  }

  Widget _buildSongTypeTag(String? type) {
    String tagText = '';
    Color tagColor = Colors.grey;
    
    if (type != null) {
      if (type.toLowerCase() == 'dx') {
        tagText = 'DX';
        tagColor = AppColors.warningOrange(Theme.of(context).brightness);
      } else if (type.toLowerCase() == 'sd') {
        tagText = 'ST';
        tagColor = AppColors.linkBlue(Theme.of(context).brightness);
      }
    }
    
    if (tagText.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Text(
      tagText,
      style: TextStyle(
        fontSize: _textSizeM,
        fontWeight: FontWeight.bold,
        color: tagColor,
      ),
    );
  }
}