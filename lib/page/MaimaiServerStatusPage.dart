import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/MaimaiServerStatusService.dart';
import 'package:my_first_flutter_app/entity/MaimaiServerStatusEntity.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

// 服务器状态页面
class MaimaiServerStatusPage extends StatefulWidget {
  const MaimaiServerStatusPage({super.key});

  @override
  State<MaimaiServerStatusPage> createState() => _MaimaiServerStatusPageState();
}

class _MaimaiServerStatusPageState extends State<MaimaiServerStatusPage> {
  MaimaiServerStatusEntity? _serverStatus;
  Map<String, String> _serverNameMap = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadServerStatus();
  }

  // 加载服务器状态
  Future<void> _loadServerStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 并行加载服务器状态和服务器名称映射
      final statusFuture = MaimaiServerStatusService.getServerStatus();
      final nameMapFuture = MaimaiServerStatusService.getServerIdToNameMap();
      
      final status = await statusFuture;
      final nameMap = await nameMapFuture;
      
      setState(() {
        _serverStatus = status;
        _serverNameMap = nameMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载服务器状态失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 字体大小
    final titleFontSize = screenWidth * 0.06;
    
    // 自定义常量
    final Color textPrimaryColor = const Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = const BoxShadow(
      color: Colors.black12,
      blurRadius: 5.0,
      offset: Offset(2.0, 2.0),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                          '服务器状态',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: titleFontSize,
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _errorMessage,
                                    style: TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                  ElevatedButton(
                                    onPressed: _loadServerStatus,
                                    child: const Text('重试'),
                                  ),
                                ],
                              ),
                            )
                          : _buildServerStatusContent(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建图例卡片
  Widget _buildLegendCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final smallFontSize = screenWidth * 0.03;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '状态图例',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 故障（红色）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse('#ff0000'.substring(1), radix: 16) + 0xFF000000),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('故障', style: TextStyle(fontSize: smallFontSize)),
                    ],
                  ),
                ),
                // 正常（绿色）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse('#00ff00'.substring(1), radix: 16) + 0xFF000000),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('正常', style: TextStyle(fontSize: smallFontSize)),
                    ],
                  ),
                ),
                // 重试中（橙色）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse('#ffaa00'.substring(1), radix: 16) + 0xFF000000),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('重试中', style: TextStyle(fontSize: smallFontSize)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建服务器状态内容
  Widget _buildServerStatusContent() {
    if (_serverStatus == null) {
      return const Center(child: Text('服务器状态数据为空'));
    }

    final serverIds = _serverStatus!.heartbeatList.getServerIds();
    if (serverIds.isEmpty) {
      return const Center(child: Text('没有服务器数据'));
    }

    // 构建服务器卡片列表
    final serverCards = serverIds.map((serverId) {
      final latestHeartbeat = _serverStatus!.heartbeatList.getLatestHeartbeat(serverId);
      return _buildServerCard(serverId, latestHeartbeat);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 图例卡片
          _buildLegendCard(),
          // 服务器卡片列表
          ...serverCards,
        ],
      ),
    );
  }

  // 根据在线率获取颜色
  Color _getUptimeColor(double uptime) {
    if (uptime >= 90) {
      return Colors.green; // 90-100% 为绿色
    } else if (uptime >= 70) {
      return Colors.orange; // 70-90% 为橙色
    } else {
      return Colors.red; // 其余为红色
    }
  }

  // 根据延迟获取颜色
  Color _getLatencyColor(int ping) {
    if (ping < 50) {
      return Colors.green; // <50ms 为绿色
    } else if (ping < 100) {
      return Colors.orange; // 50-100ms 为橙色
    } else {
      return Colors.red; // >100ms 为红色
    }
  }

  // 构建服务器卡片
  Widget _buildServerCard(String serverId, HeartbeatItem? heartbeat) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentFontSize = screenWidth * 0.04;
    final smallFontSize = screenWidth * 0.03;

    // 获取服务器名称
    final serverName = _serverNameMap[serverId] ?? '服务器 $serverId';

    // 获取最近50条心跳记录
    List<HeartbeatItem> recentHeartbeats = [];
    if (_serverStatus != null) {
      final serverHeartbeats = _serverStatus!.heartbeatList.items[serverId];
      if (serverHeartbeats != null) {
        // 取最近的50条记录
        recentHeartbeats = serverHeartbeats.reversed.take(50).toList().reversed.toList();
      }
    }

    // 获取对应服务器的uptime数据
    double uptimePercentage = 0.0;
    if (_serverStatus != null) {
      final uptimeList = _serverStatus!.uptimeList;
      // 根据serverId获取对应的uptime数据
      switch (serverId) {
        case '1':
          uptimePercentage = uptimeList.uptime1_24.toDouble();
          break;
        case '4':
          uptimePercentage = uptimeList.uptime4_24.toDouble();
          break;
        case '5':
          uptimePercentage = uptimeList.uptime5_24.toDouble();
          break;
        case '6':
          uptimePercentage = uptimeList.uptime6_24.toDouble();
          break;
        case '7':
          uptimePercentage = uptimeList.uptime7_24.toDouble();
          break;
        case '8':
          uptimePercentage = uptimeList.uptime8_24.toDouble();
          break;
        case '9':
          uptimePercentage = uptimeList.uptime9_24.toDouble();
          break;
        case '10':
          uptimePercentage = uptimeList.uptime10_24.toDouble();
          break;
        case '11':
          uptimePercentage = uptimeList.uptime11_24.toDouble();
          break;
        case '12':
          uptimePercentage = uptimeList.uptime12_24.toDouble();
          break;
        case '13':
          uptimePercentage = uptimeList.uptime13_24.toDouble();
          break;
        case '14':
          uptimePercentage = uptimeList.uptime14_24.toDouble();
          break;
        case '15':
          uptimePercentage = uptimeList.uptime15_24.toDouble();
          break;
        case '16':
          uptimePercentage = uptimeList.uptime16_24.toDouble();
          break;
        case '17':
          uptimePercentage = uptimeList.uptime17_24.toDouble();
          break;
        case '18':
          uptimePercentage = uptimeList.uptime18_24.toDouble();
          break;
      }
    }



    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：服务器名称
            Text(
              serverName,
              style: TextStyle(
                fontSize: contentFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // 第二行：20个带颜色的小格子
            Row(
              children: recentHeartbeats.map((item) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(int.parse(item.getStatusColor().substring(1), radix: 16) + 0xFF000000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            

            
            // 第三行：最后更新时间
            if (heartbeat != null)
              Text(
                '最后更新: ${heartbeat.time}',
                style: TextStyle(fontSize: smallFontSize, color: Colors.grey),
              ),
            
            // 第四行：延迟和在线率（左对齐）
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: heartbeat != null && heartbeat.ping != null ? _getLatencyColor(heartbeat.ping!) : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '延迟: ${heartbeat != null && heartbeat.ping != null ? '${heartbeat.ping} ms' : '-- ms'}',
                      style: TextStyle(
                        fontSize: smallFontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getUptimeColor(uptimePercentage * 100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '在线率: ${(uptimePercentage * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: smallFontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // 消息（如果有）
            if (heartbeat != null && heartbeat.msg.isNotEmpty)
              Text(
                '消息: ${heartbeat.msg}',
                style: TextStyle(fontSize: smallFontSize, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}