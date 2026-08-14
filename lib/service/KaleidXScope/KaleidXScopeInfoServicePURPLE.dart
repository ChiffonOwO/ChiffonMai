import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/KaleidXScope/KaleidXScopeGate.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

class KaleidXScopeInfoServicePURPLE {
  static final KaleidXScopeInfoServicePURPLE _instance = KaleidXScopeInfoServicePURPLE._internal();
  factory KaleidXScopeInfoServicePURPLE() => _instance;
  KaleidXScopeInfoServicePURPLE._internal();

  static const String _gateColor = 'purple';
  KaleidXScopeGate? _cachedGate;
  bool _isLoading = false;

  Future<KaleidXScopeGate> fetchGateData() async {
    if (_cachedGate != null) return _cachedGate!;
    if (_isLoading) {
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

  Future<List<Song>> getPurpleGateSongs() async {
    final gate = await fetchGateData();
    final ids = gate.songs['gate'] ?? [];
    return await getSongsByIds(ids);
  }

  Future<List<Song>> getSongsByGateType(String gateType) async {
    switch (gateType) {
      case 'purple':
      case '紫门':
        return await getPurpleGateSongs();
      default:
        return [];
    }
  }

  Future<Map<String, List<Song>>> loadTrackSongs() async {
    final Map<String, List<Song>> result = {'track1': [], 'track2': [], 'track3': []};
    try {
      final gate = await fetchGateData();
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return result;
      for (final track in ['track1', 'track2', 'track3']) {
        final ids = gate.songs[track] ?? [];
        result[track] = ids
            .map((id) { try { return allSongs.firstWhere((s) => int.parse(s.id) == id); } catch (_) { return null; } })
            .whereType<Song>()
            .toList();
      }
    } catch (e) {
      debugPrint('加载Track歌曲失败: $e');
    }
    return result;
  }

  Future<List<KaleidXScopeChallenge>> getChallenges() async {
    final gate = await fetchGateData();
    return gate.challenges;
  }

  Future<KaleidXScopeGate> getGateInfo() async {
    return await fetchGateData();
  }
}
