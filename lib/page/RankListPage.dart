import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/service/RankListService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/page/RankDetailPage.dart';

class RankListPage extends StatefulWidget {
  const RankListPage({super.key});

  @override
  State<RankListPage> createState() => _RankListPageState();
}

class _RankListPageState extends State<RankListPage> {
  final RankListService _service = RankListService();
  String? _selectedRank;
  
  late double _paddingXS;
  late double _paddingS;
  late double _paddingM;
  late double _paddingL;
  late double _borderRadiusSmall;
  late double _textSizeM;
  late double _scaleFactor;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _scaleFactor = screenWidth / 375.0;
    _paddingXS = 4.0 * _scaleFactor;
    _paddingS = 8.0 * _scaleFactor;
    _paddingM = 12.0 * _scaleFactor;
    _paddingL = 16.0 * _scaleFactor;
    _borderRadiusSmall = 8.0 * _scaleFactor;
    _textSizeM = 12.0 * _scaleFactor;

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
                          '段位表',
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(_paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择段位',
                          style: TextStyle(
                            fontSize: _textSizeM,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700]!,
                          ),
                        ),
                        SizedBox(height: _paddingXS),
                        Column(
                          children: _service.getRankOptions().map((rank) {
                            final rankData = _service.getRankData(rank);
                            final isNormalRank = ['初段', '二段', '三段', '四段', '五段', '六段', '七段', '八段', '九段', '十段'].contains(rank);
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: _paddingXS),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedRank == rank
                                      ? Colors.blue
                                      : Colors.grey[100]!,
                                  foregroundColor: Colors.black,
                                  minimumSize: Size(double.infinity, 56 * _scaleFactor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                                    side: BorderSide(
                                      color: isNormalRank ? Color(0xFF8B4513) : Colors.purple,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RankDetailPage(rankName: rank),
                                    ),
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingXS),
                                      decoration: BoxDecoration(
                                        color: isNormalRank ? Color(0xFF8B4513) : Colors.purple,
                                        borderRadius: BorderRadius.circular(_borderRadiusSmall),
                                      ),
                                      child: Text(
                                        rank,
                                        style: TextStyle(
                                          fontSize: _textSizeM,
                                          fontWeight: FontWeight.bold,
                                          color: isNormalRank ? Colors.white : Color(0xFFE6E6FA),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: _paddingS),
                                    if (rankData != null)
                                      Row(
                                        children: List.generate(4, (index) {
                                          final songId = rankData.songIds[index];
                                          final levelIndex = rankData.levelIndexes[index];
                                          return Container(
                                            margin: EdgeInsets.only(left: index > 0 ? _paddingXS : 0),
                                            width: 40 * _scaleFactor,
                                            height: 40 * _scaleFactor,
                                            child: Stack(
                                              children: [
                                                CoverUtil.buildCoverWidgetWithContext(
                                                  context,
                                                  songId.isNotEmpty ? songId : '0',
                                                  40 * _scaleFactor,
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
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
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