import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class ArcadeMarkerCluster<T> {
  final LatLng center;
  final List<T> items;
  const ArcadeMarkerCluster(this.center, this.items);
}

class _PixelCluster<T> {
  double x;
  double y;
  final List<T> items;
  _PixelCluster(this.x, this.y, this.items);
}

/// 按当前缩放级别的屏幕距离聚合，聚合点仍参与下一轮合并。
/// 中心以原始机厅数量加权，避免再次合并后偏向小聚合点。
List<ArcadeMarkerCluster<T>> clusterArcadeMarkers<T>(
    List<T> items, LatLng Function(T) location, double zoom,
    {double radius = 48}) {
  final world = 256 * math.pow(2, zoom);
  var nodes = items.map((item) {
    final point = location(item);
    final latitude = point.latitude.clamp(-85.05112878, 85.05112878);
    final sin = math.sin(latitude * math.pi / 180);
    return _PixelCluster<T>((point.longitude + 180) / 360 * world,
        (.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi)) * world, [item]);
  }).toList();
  while (nodes.length > 1) {
    final parent = List.generate(nodes.length, (index) => index);
    int find(int index) {
      while (parent[index] != index) {
        parent[index] = parent[parent[index]];
        index = parent[index];
      }
      return index;
    }

    final grid = <(int, int), List<int>>{};
    var merged = false;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final gy = (node.y / radius).floor();
      // 跨越日期变更线的机厅也应该能合并。
      for (final shift in [-world, 0.0, world]) {
        final gx = ((node.x + shift) / radius).floor();
        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            for (final j in grid[(gx + dx, gy + dy)] ?? const <int>[]) {
              final other = nodes[j];
              final distanceX = (node.x + shift - other.x).abs();
              if (distanceX * distanceX + math.pow(node.y - other.y, 2) <=
                  radius * radius) {
                final a = find(i), b = find(j);
                if (a != b) {
                  parent[a] = b;
                  merged = true;
                }
              }
            }
          }
        }
      }
      grid.putIfAbsent(((node.x / radius).floor(), gy), () => []).add(i);
    }
    if (!merged) break;
    final groups = <int, List<_PixelCluster<T>>>{};
    for (var i = 0; i < nodes.length; i++) {
      groups.putIfAbsent(find(i), () => []).add(nodes[i]);
    }
    nodes = groups.values.map((group) {
      final members = <T>[];
      var x = 0.0, y = 0.0;
      final anchor = group.first.x;
      for (final node in group) {
        var adjustedX = node.x;
        if (adjustedX - anchor > world / 2) adjustedX -= world;
        if (anchor - adjustedX > world / 2) adjustedX += world;
        x += adjustedX * node.items.length;
        y += node.y * node.items.length;
        members.addAll(node.items);
      }
      return _PixelCluster<T>(
          (x / members.length) % world, y / members.length, members);
    }).toList();
  }
  return nodes.map((node) {
    final latitude =
        (2 * math.atan(math.exp((.5 - node.y / world) * 2 * math.pi)) -
                math.pi / 2) *
            180 /
            math.pi;
    return ArcadeMarkerCluster<T>(
        LatLng(latitude, node.x / world * 360 - 180), node.items);
  }).toList();
}
