import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/KaleidXScope/KaleidXScopeGate.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

class KaleidXScopeInfoServiceBLUE {
  static final KaleidXScopeInfoServiceBLUE _instance = KaleidXScopeInfoServiceBLUE._internal();
  factory KaleidXScopeInfoServiceBLUE() => _instance;
  KaleidXScopeInfoServiceBLUE._internal();

  static const String _gateColor = 'blue';
  KaleidXScopeGate? _cachedGate;
  bool _isLoading = false;

  /// 获取门数据（自动缓存）
  Future<KaleidXScopeGate> fetchGateData() async {
    if (_cachedGate != null) return _cachedGate!;

    if (_isLoading) {
      // 如果正在加载，等待一小段时间后返回缓存
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_cachedGate != null) return _cachedGate!;
      }
      throw Exception('加载门数据超时');
    }

    _isLoading = true;
    try {
      final url = Uri.parse('${ApiUrls.KaleidXScopeBaseUrl}/gates/$_gateColor');
      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          _cachedGate = KaleidXScopeGate.fromJson(json['data'] as Map<String, dynamic>);
          return _cachedGate!;
        }
      }
      throw Exception('获取门数据失败: ${response.statusCode}');
    } finally {
      _isLoading = false;
    }
  }

  /// 从缓存中获取指定ID列表的歌曲
  Future<List<Song>> getSongsByIds(List<int> songIds) async {
    final List<Song> result = [];
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    if (songs == null) return result;

    for (final id in songIds) {
      try {
        final song = songs.firstWhere((s) => int.parse(s.id) == id);
        result.add(song);
      } catch (e) {
        debugPrint('未找到歌曲ID: $id');
      }
    }
    return result;
  }

  /// 获取蓝色之门的歌曲列表
  Future<List<Song>> getBlueGateSongs() async {
    final gate = await fetchGateData();
    final ids = gate.songs['gate'] ?? [];
    return await getSongsByIds(ids);
  }

  /// 根据门的类型获取歌曲列表
  Future<List<Song>> getSongsByGateType(String gateType) async {
    switch (gateType) {
      case 'blue':
      case '蓝色之门':
        return await getBlueGateSongs();
      default:
        return [];
    }
  }

  /// 加载Track歌曲
  Future<Map<String, List<Song>>> loadTrackSongs() async {
    final Map<String, List<Song>> result = {
      'track1': [],
      'track2': [],
      'track3': [],
    };

    try {
      final gate = await fetchGateData();
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return result;

      for (final track in ['track1', 'track2', 'track3']) {
        final ids = gate.songs[track] ?? [];
        result[track] = ids
            .map((id) {
              try {
                return allSongs.firstWhere((s) => int.parse(s.id) == id);
              } catch (_) {
                return null;
              }
            })
            .whereType<Song>()
            .toList();
      }
    } catch (e) {
      debugPrint('加载Track歌曲失败: $e');
    }

    return result;
  }

  /// 获取挑战数据
  Future<List<KaleidXScopeChallenge>> getChallenges() async {
    final gate = await fetchGateData();
    return gate.challenges;
  }

  /// 获取门基础信息
  Future<KaleidXScopeGate> getGateInfo() async {
    return await fetchGateData();
  }
}
