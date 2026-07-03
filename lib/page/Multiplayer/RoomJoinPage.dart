import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';

class RoomJoinPage extends StatefulWidget {
  const RoomJoinPage({super.key});

  @override
  State<RoomJoinPage> createState() => _RoomJoinPageState();
}

class _RoomJoinPageState extends State<RoomJoinPage> {
  final TextEditingController _roomIdController = TextEditingController();
  bool _isJoining = false;

  void _handleJoin() async {
    String roomId = _roomIdController.text.trim().toLowerCase();
    
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入房间ID')),
      );
      return;
    }
    
    setState(() => _isJoining = true);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    Navigator.pop(context, roomId);
  }

  void _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _roomIdController.text = data.text!.toLowerCase();
      });
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
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '加入房间',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
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

              // 主内容区域 - 白色区域，使用 Expanded 占据剩余空间
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
                    child: Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + paddingL),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(paddingM),
                            decoration: BoxDecoration(
                              color: AppColors.linkBlue(brightness).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(borderRadiusSmall),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.info_outline, size: 32 * scaleFactor, color: Colors.blue),
                                SizedBox(height: paddingM),
                                Text(
                                  '请输入房间ID',
                                  style: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: paddingS),
                                Text(
                                  '房间ID格式: abc123',
                                  style: TextStyle(fontSize: 12 * scaleFactor, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: paddingL * 1.5),
                          TextField(
                            controller: _roomIdController,
                            decoration: InputDecoration(
                              hintText: 'abc123',
                              labelText: '房间ID',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.paste),
                                onPressed: _handlePaste,
                              ),
                            ),
                            textCapitalization: TextCapitalization.none,
                            onSubmitted: (_) => _handleJoin(),
                          ),
                          SizedBox(height: paddingM),
                          ElevatedButton(
                            onPressed: _handleJoin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.onSurface,
                              padding: EdgeInsets.symmetric(vertical: 16 * scaleFactor),
                              minimumSize: Size(double.infinity, 50 * scaleFactor),
                            ),
                            child: _isJoining
                                ? SizedBox(width: 24 * scaleFactor, height: 24 * scaleFactor, child: CircularProgressIndicator(color: Colors.white))
                                : Text('加入房间', style: TextStyle(color: Colors.white, fontSize: 16 * scaleFactor)),
                          ),
                          SizedBox(height: paddingL),
                          const Divider(),
                          SizedBox(height: paddingM),
                          Text(
                            '如何获取房间ID?',
                            style: TextStyle(fontSize: 14 * scaleFactor, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: paddingS),
                          Text(
                            '创建房间后，房主会获得一个房间ID。\n请让房主将房间ID发送给你，\n然后在此输入加入游戏。',
                            style: TextStyle(fontSize: 12 * scaleFactor, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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