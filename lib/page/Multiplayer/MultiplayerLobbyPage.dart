import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomCreatePage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomJoinPage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/GameRoomPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';

class MultiplayerLobbyPage extends StatefulWidget {
  const MultiplayerLobbyPage({super.key});

  @override
  State<MultiplayerLobbyPage> createState() => _MultiplayerLobbyPageState();
}

class _MultiplayerLobbyPageState extends State<MultiplayerLobbyPage> {
  final MultiplayerManager _manager = MultiplayerManager();
  bool _isCreating = false;
  bool _isJoining = false;

  void _handleCreateRoom() async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomCreatePage()),
    );
    
    setState(() => _isCreating = false);
    
    if (result != null && result is RoomEntity) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GameRoomPage(room: result)),
      );
    }
  }

  void _handleJoinRoom() async {
    if (_isJoining) return;
    
    setState(() => _isJoining = true);
    
    final roomId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomJoinPage()),
    );
    
    setState(() => _isJoining = false);
    
    if (roomId != null && roomId is String) {
      RoomEntity? room = await _manager.joinRoom(roomId);
      if (room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GameRoomPage(room: room)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加入房间失败')),
        );
      }
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
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(paddingM, 48, paddingM, paddingL),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: const Color.fromARGB(255, 84, 97, 97)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '多人游戏',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 84, 97, 97),
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(paddingM),
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.15),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 150 * scaleFactor,
                          child: ElevatedButton(
                            onPressed: _handleCreateRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_box, size: 48 * scaleFactor, color: Colors.white),
                                SizedBox(height: paddingM),
                                Text(
                                  '创建房间',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: paddingL),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 150 * scaleFactor,
                          child: ElevatedButton(
                            onPressed: _handleJoinRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color.fromARGB(255, 84, 97, 97), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_add, size: 48 * scaleFactor, color: const Color.fromARGB(255, 84, 97, 97)),
                                SizedBox(height: paddingM),
                                Text(
                                  '加入房间',
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 84, 97, 97),
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  double get screenHeight => MediaQuery.of(context).size.height;
}