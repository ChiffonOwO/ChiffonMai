import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomCreatePage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomJoinPage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/GameRoomPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';
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
    final brightness = Theme.of(context).brightness;
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
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '多人游戏',
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

              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(paddingS, 0, paddingS, paddingL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppConstants.defaultShadow(brightness)],
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
                              backgroundColor: Theme.of(context).colorScheme.onSurface,
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
                              side: BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_add, size: 48 * scaleFactor, color: Theme.of(context).colorScheme.onSurface),
                                SizedBox(height: paddingM),
                                Text(
                                  '加入房间',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
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