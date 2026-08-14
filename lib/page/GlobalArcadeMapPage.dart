import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/entity/nearcade/NearCadeShop.dart';
import 'package:my_first_flutter_app/service/NearCadeService.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

// 缓存 Key
const _cacheKey = 'nearcade_shops_cache';
const _cacheTimeKey = 'nearcade_shops_cache_time';

// 视口内最大标点数
const _maxVisibleMarkers = 200;

class GlobalArcadeMapPage extends StatefulWidget {
  const GlobalArcadeMapPage({super.key});

  @override
  _GlobalArcadeMapPageState createState() => _GlobalArcadeMapPageState();
}

class _GlobalArcadeMapPageState extends State<GlobalArcadeMapPage> {
  final MapController _mapController = MapController();
  final List<Shop> _shops = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _lastFetchTime;

  // 搜索与筛选
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final Set<String> _selectedGames = {};
  List<String> _allGameNames = [];
  bool _showFilterPanel = false;
  bool _showSearchResults = false;

  LatLngBounds? _visibleBounds;

  static const _defaultCenter = LatLng(35.0, 115.0);
  static const _defaultZoom = 4.0;

  @override
  void initState() {
    super.initState();
    _initLoad();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        setState(() => _showSearchResults = true);
      } else {
        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSearchResults = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// 仅读取缓存，不自动拉取网络
  Future<void> _initLoad() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    final cachedTime = prefs.getInt(_cacheTimeKey);

    if (cachedJson != null) {
      try {
        final data = NearCadeShop.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        _applyShopData(data.shops);
        if (cachedTime != null) {
          _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(cachedTime);
        }
      } catch (_) {
        // 缓存损坏，忽略
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchFromNetwork(SharedPreferences prefs) async {
    try {
      final allShops = await NearCadeService().getAllShops();
      if (allShops.isNotEmpty) {
        _applyShopData(allShops);

        // 写入缓存
        final now = DateTime.now();
        final shopJsonList = allShops.map((s) => _shopToJson(s)).toList();
        final cacheData = jsonEncode({
          'shops': shopJsonList,
          'totalCount': allShops.length,
          'currentPage': 1,
          'hasNextPage': false,
          'hasPrevPage': false,
        });
        await prefs.setString(_cacheKey, cacheData);
        await prefs.setInt(_cacheTimeKey, now.millisecondsSinceEpoch);
        _lastFetchTime = now;

        setState(() {});
      }
    } catch (e) {
      if (_shops.isEmpty) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _applyShopData(List<Shop> shops) {
    final gameNames = <String>{};
    for (final shop in shops) {
      for (final game in shop.games) {
        if (game.name.isNotEmpty) gameNames.add(game.name);
      }
    }
    _shops.clear();
    _shops.addAll(shops);
    _allGameNames = gameNames.toList()..sort();
  }

  /// 手动刷新
  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await _fetchFromNetwork(prefs);
    setState(() => _isLoading = false);
  }

  // ---- 简单的 Shop → JSON 序列化 ----
  Map<String, dynamic> _shopToJson(Shop s) => {
    '_id': s.id,
    'name': s.name,
    'shopId': s.shopId,
    'comment': s.comment,
    'isClaimed': s.isClaimed,
    'isLocked': s.isLocked,
    'isOpen': s.isOpen,
    'ownerId': s.ownerId,
    'createdAt': s.createdAt.toIso8601String(),
    'updatedAt': s.updatedAt.toIso8601String(),
    'address': {
      'detailed': s.address.detailed,
      'general': s.address.general,
      'region': s.address.region,
    },
    'location': {
      'type': 'Point',
      'coordinates': s.location.coordinates,
    },
    'games': s.games.map((g) => {
      'gameId': g.gameId,
      'name': g.name,
      'titleId': g.titleId,
      'version': g.version,
      'quantity': g.quantity,
      'comment': g.comment,
      'cost': g.cost,
    }).toList(),
    'openingHours': s.openingHours.map((day) =>
        day.map((h) => {'hour': h.hour, 'minute': h.minute}).toList()
    ).toList(),
    'timezone': s.timezone == null ? null : {
      'name': s.timezone!.name,
      'offset': s.timezone!.offset,
    },
  };

  // ---- 筛选 ----
  List<Shop> get _filteredShops {
    return _shops.where((shop) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!shop.name.toLowerCase().contains(q) &&
            !shop.address.detailed.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedGames.isNotEmpty) {
        final shopGameNames = shop.games.map((g) => g.name).toSet();
        if (!_selectedGames.any((g) => shopGameNames.contains(g))) return false;
      }
      return true;
    }).toList();
  }

  List<Shop> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    return _filteredShops.take(20).toList();
  }

  Color _getShopMarkerColor(List<Game> games) {
    final names = games.map((g) => g.name.toLowerCase()).toSet();
    if (names.any((n) => n.contains('maimai') || n.contains('舞萌'))) return Colors.red;
    if (names.any((n) => n.contains('chunithm') || n.contains('中二'))) return Colors.orange;
    if (names.any((n) => n.contains('ongeki') || n.contains('音击'))) return Colors.purple;
    if (names.any((n) => n.contains('taiko') || n.contains('太鼓'))) return Colors.blue;
    if (names.any((n) => n.contains('sdvx') || n.contains('旋钮'))) return Colors.teal;
    return games.isNotEmpty ? Colors.green : Colors.grey;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final shop in _filteredShops) {
      if (shop.location.coordinates.length < 2) continue;
      final point = LatLng(shop.location.coordinates[1], shop.location.coordinates[0]);
      if (_visibleBounds != null && !_visibleBounds!.contains(point)) continue;

      markers.add(Marker(
        point: point,
        width: 26,
        height: 26,
        child: GestureDetector(
          onTap: () => _showShopDetail(shop),
          child: Container(
            decoration: BoxDecoration(
              color: _getShopMarkerColor(shop.games).withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Center(child: Icon(Icons.videogame_asset, color: Colors.white, size: 12)),
          ),
        ),
      ));

      if (markers.length >= _maxVisibleMarkers) break;
    }
    return markers;
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _locateUser,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: CircleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
        ),
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.my_location, size: 22,
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  Future<void> _locateUser() async {
    debugPrint('=== 定位按钮被点击 ===');
    try {
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请先开启设备定位服务')),
          );
        }
        return;
      }

      // 检查/请求权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('定位权限已被永久拒绝，请在系统设置中开启')),
          );
        }
        return;
      }

      // 优先用最近已知位置（即时返回），没有才实时定位
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8),
            ),
          );
        } catch (_) {
          position = null;
        }
      }

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法获取当前位置，请确认已开启定位服务且信号良好')),
          );
        }
        return;
      }

      final userLatLng = LatLng(position.latitude, position.longitude);
      _mapController.move(userLatLng, 14.0);
    } catch (e) {
      debugPrint('定位失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('定位失败: $e')),
        );
      }
    }
  }

  void _focusOnShop(Shop shop) {
    if (shop.location.coordinates.length < 2) return;
    _mapController.move(LatLng(shop.location.coordinates[1], shop.location.coordinates[0]), 16.0);
    setState(() {
      _showSearchResults = false;
      _searchFocusNode.unfocus();
    });
    // 等地图动画完成后弹出详情
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 600), () {
        if (mounted) _showShopDetail(shop);
      });
    });
  }

  String _formatLastFetchTime() {
    if (_lastFetchTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(_lastFetchTime!);
    if (diff.inMinutes < 1) return '刚刚更新';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${_lastFetchTime!.month}/${_lastFetchTime!.day} ${_lastFetchTime!.hour.toString().padLeft(2, '0')}:${_lastFetchTime!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final filtered = _filteredShops;
    final visibleInBounds = _visibleBounds != null
        ? filtered.where((s) {
            if (s.location.coordinates.length < 2) return false;
            return _visibleBounds!.contains(LatLng(s.location.coordinates[1], s.location.coordinates[0]));
          }).length
        : filtered.length;
    final shownCount = visibleInBounds.clamp(0, _maxVisibleMarkers);
    final isFiltering = _searchQuery.isNotEmpty || _selectedGames.isNotEmpty;
    final countLabel = isFiltering ? '${filtered.length}家' : '共${_shops.length}家';

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('全球音游街机地图',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: MediaQuery.of(context).size.width * 0.055,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: _isLoading ? null : _refresh,
                    ),
                  ],
                ),
              ),

              // 状态栏
              if (!_isLoading && _error == null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(countLabel,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (isFiltering)
                        Text(' (筛选)',
                            style: TextStyle(fontSize: 10, color: Colors.orange)),
                      if (visibleInBounds > _maxVisibleMarkers)
                        Text(' 显示$shownCount',
                            style: TextStyle(fontSize: 10, color: Colors.orange)),
                      const Spacer(),
                      if (_lastFetchTime != null)
                        Text('上次更新: ${_formatLastFetchTime()}',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),

              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _searchFocusNode.unfocus();
                    setState(() => _showSearchResults = false);
                  },
                  child: Container(
                    margin: EdgeInsets.fromLTRB(4, 4, 4, 10 + safeBottom),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        _buildMapContent(),
                        if (!_isLoading && _error == null) _buildFloatingSearch(filtered.length),
                        // 定位按钮
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: _buildLocationButton(),
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

  Widget _buildFloatingSearch(int filteredCount) {
    final results = _showSearchResults ? _searchResults : <Shop>[];

    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: results.isEmpty && !_showFilterPanel ? Radius.circular(8) : Radius.zero,
              ),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                SizedBox(width: 8),
                Icon(Icons.search, size: 18, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索店名或地址',
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v.trim();
                        _showSearchResults = v.trim().isNotEmpty;
                      });
                    },
                    onTap: () {
                      if (_searchQuery.isNotEmpty) setState(() => _showSearchResults = true);
                    },
                  ),
                ),
                // 搜索结果计数
                if (_searchQuery.isNotEmpty || _selectedGames.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$filteredCount', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _showSearchResults = false;
                      });
                    },
                    child: Icon(Icons.clear, size: 16, color: Colors.grey),
                  ),
                GestureDetector(
                  onTap: () => setState(() => _showFilterPanel = !_showFilterPanel),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Icon(Icons.filter_list, size: 16,
                        color: _selectedGames.isNotEmpty ? Colors.red : Colors.grey),
                  ),
                ),
                SizedBox(width: 4),
              ],
            ),
          ),

          // 搜索结果列表
          if (results.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: results.isEmpty && !_showFilterPanel
                    ? null
                    : BorderRadius.vertical(bottom: Radius.circular(8)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 12, endIndent: 12),
                itemBuilder: (_, i) {
                  final shop = results[i];
                  final games = shop.games.map((g) => g.name).join(' / ');
                  final region = shop.address.general.join(' ');
                  return InkWell(
                    onTap: () => _focusOnShop(shop),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(shop.name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (region.isNotEmpty)
                                  Text(region,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (games.isNotEmpty)
                                  Text(games,
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.my_location, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 筛选面板
          if (_showFilterPanel && _allGameNames.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              constraints: BoxConstraints(maxHeight: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('机台筛选', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_selectedGames.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _selectedGames.clear()),
                          child: Text('清除', style: TextStyle(fontSize: 12, color: Colors.red)),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _allGameNames.map((name) {
                          final selected = _selectedGames.contains(name);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selected ? _selectedGames.remove(name) : _selectedGames.add(name);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected ? Colors.red.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? Colors.red : Colors.grey.withOpacity(0.3)),
                              ),
                              child: Text(name,
                                  style: TextStyle(fontSize: 11, color: selected ? Colors.red : Colors.grey.shade700)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 12),
            Text('加载失败', style: TextStyle(fontSize: 16)),
            Text(_error!, style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _refresh, child: Text('重试')),
          ],
        ),
      );
    }

    if (_shops.isEmpty) {
      return Center(child: Text('暂无店铺数据', style: TextStyle(color: Colors.grey)));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
        minZoom: 2,
        maxZoom: 18,
        onMapEvent: (_) {
          final bounds = _mapController.camera.visibleBounds;
          if (bounds != _visibleBounds) setState(() => _visibleBounds = bounds);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
          subdomains: const ['1', '2', '3', '4'],
          userAgentPackageName: 'com.example.my_first_flutter_app',
        ),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  void _showShopDetail(Shop shop) {
    final gameList = shop.games
        .map((g) => '${g.name}${g.version.isNotEmpty ? ' (${g.version})' : ''} x${g.quantity}')
        .join('\n');
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        constraints: BoxConstraints(maxHeight: 350 + bottomPadding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(shop.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('📍 ${shop.address.detailed}', style: TextStyle(fontSize: 14)),
              Text('🏙️ ${shop.address.general.join(' ')}', style: TextStyle(fontSize: 13, color: Colors.grey)),
              if (shop.comment.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('📝 ${shop.comment}', style: TextStyle(fontSize: 13)),
              ],
              SizedBox(height: 8),
              Text('🎮 机台:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(gameList, style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
