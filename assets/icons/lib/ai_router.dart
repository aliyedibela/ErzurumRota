import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// ======================
/// Public API
/// ======================

class RouteSegment {
  /// "walk" | "bus"
  final String kind;

  /// null for walk, otherwise line name (e.g. "K7")
  final String? line;

  /// polyline points for this segment
  final List<LatLng> points;

  const RouteSegment({required this.kind, this.line, required this.points});
}

class RouteResult {
  /// Ordered list of segments (walk -> bus [-> bus] -> walk)
  final List<RouteSegment> segments;

  /// Total meters (walk+bus). (Heuristic; bus mesafesi “stop-to-stop” arası)
  final double totalMeters;

  /// Number of transfers (hat değişimi sayısı)
  final int transfers;

  const RouteResult({
    required this.segments,
    required this.totalMeters,
    required this.transfers,
  });
}

class AiRouter {
  AiRouter({
    this.walkMaxMeters = 600,
    this.transferRadiusMeters = 30,
    this.maxTransfers = 2,
  });

  /// Başlangıç/bitiş için en fazla yürünecek mesafe
  final double walkMaxMeters;

  /// Hatlar arası transfer için düğümler arası “yakınlık” eşiği
  final double transferRadiusMeters;

  /// En fazla kaç transfer (hat değişimi)
  final int maxTransfers;

  final _Graph _graph = _Graph();
  Future<void> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _graph.buildFromJson(data, transferRadiusMeters: transferRadiusMeters);
  }

  /// Doğrudan hat var mı? (start/end için en yakın real stop’u alır)
  RouteResult? _tryDirect(LatLng start, LatLng end) {
    final s = _graph.nearestNode(start);
    final e = _graph.nearestNode(end);

    if (s == null || e == null) return null;

    // Aynı hattı paylaşan tüm hatlar üzerinden kontrol et:
    final common = _graph.linesOfNode(s).toSet()
      ..retainAll(_graph.linesOfNode(e));

    for (final line in common) {
      final ids = _graph.lineOrder[line]!;
      final i1 = ids.indexOf(s);
      final i2 = ids.indexOf(e);
      if (i1 >= 0 && i2 >= 0 && i1 < i2) {
        // doğru yön: s->...->e
        final pts = ids.sublist(i1, i2 + 1).map(_graph.nodeLatLng).toList();

        // start ve end’e portal-walk izin ver (limit dahilinde)
        final walkIn = _graph._maybeWalkPortal(start, s, walkMaxMeters);
        final walkOut = _graph._maybeWalkPortal(end, e, walkMaxMeters);

        final segs = <RouteSegment>[];
        if (walkIn.isNotEmpty)
          segs.add(RouteSegment(kind: 'walk', points: walkIn));
        segs.add(RouteSegment(kind: 'bus', line: line, points: pts));
        if (walkOut.isNotEmpty)
          segs.add(RouteSegment(kind: 'walk', points: walkOut));

        final total = _sumMeters(segs);
        return RouteResult(segments: segs, totalMeters: total, transfers: 0);
      }
    }
    return null;
  }

  /// En fazla 2 aktarma ile en iyi rotayı bul
  RouteResult? findRoute(LatLng start, LatLng end) {
    // 1) Doğrudan hat varsa hemen dön
    final direct = _tryDirect(start, end);
    if (direct != null) return direct;

    // 2) Dijkstra + transfer kısıtı
    final sPortalId = _graph.addPortal(start, maxWalk: walkMaxMeters);
    final ePortalId = _graph.addPortal(end, maxWalk: walkMaxMeters);

    final state = _graph._dijkstraLimitedTransfers(
      sPortalId,
      ePortalId,
      maxTransfers: maxTransfers,
    );
    if (state == null) return null;

    final pathNodeIds = state.path;
    final segments = _graph._nodesToSegments(pathNodeIds);

    final total = _sumMeters(segments);
    final transfers = _countTransfers(segments);

    return RouteResult(
      segments: segments,
      totalMeters: total,
      transfers: transfers,
    );
  }
}

/// ======================
/// Internal graph
/// ======================

class _Edge {
  final int to;
  final double w; // weight (meters, sonra AI cost)
  final String kind; // 'bus'|'walk'
  final String? line; // bus line or null

  _Edge({required this.to, required this.w, required this.kind, this.line});
}

class _Graph {
  // nodes: id -> LatLng
  final List<LatLng> nodes = [];
  // adjacency list
  final List<List<_Edge>> adj = [];

  // nodeIndex: roundedKey -> nodeId  (aynı koordinatta olan duraklar tek düğüm)
  final Map<String, int> nodeIndex = {};

  // lineOrder: hat -> nodeId listesi (sıralı)
  final Map<String, List<int>> lineOrder = {};

  // nodeLines: nodeId -> bu düğümü içeren hatlar
  final Map<int, Set<String>> nodeLines = {};

  // KD gibi ağır yapmayalım; basit arama yeterli (şehir ölçeğinde 1–2 ms)
  int _addOrGetNode(LatLng p, {double round = 1e-5}) {
    final key =
        '${(p.latitude / round).round() * round},${(p.longitude / round).round() * round}';
    final id = nodeIndex[key];
    if (id != null) return id;
    final newId = nodes.length;
    nodes.add(p);
    adj.add(<_Edge>[]);
    nodeIndex[key] = newId;
    return newId;
  }

  void _addEdge(
    int a,
    int b,
    double meters,
    String kind, {
    String? line,
    bool bidir = true,
  }) {
    adj[a].add(_Edge(to: b, w: meters, kind: kind, line: line));
    if (bidir) {
      adj[b].add(_Edge(to: a, w: meters, kind: kind, line: line));
    }
  }

  void buildFromJson(
    Map<String, dynamic> data, {
    required double transferRadiusMeters,
  }) {
    // 1) Hatlardaki durakları tekilleştir, sıralı node listesi oluştur
    data.forEach((lineName, v) {
      final stops = (v as Map<String, dynamic>)['stops'] as List;
      final ids = <int>[];
      for (final s in stops) {
        final lat = (s[0] as num).toDouble();
        final lon = (s[1] as num).toDouble();
        final nid = _addOrGetNode(LatLng(lat, lon));
        ids.add(nid);
        nodeLines.putIfAbsent(nid, () => <String>{}).add(lineName);
      }
      lineOrder[lineName] = ids;

      // 2) Ardışık duraklar arasında yönlü bus edge
      for (var i = 0; i < ids.length - 1; i++) {
        final a = ids[i], b = ids[i + 1];
        final d = _haversine(nodes[a], nodes[b]);
        _addEdge(a, b, d, 'bus', line: lineName, bidir: true);
      }
    });

    // 3) Transfer: Aynı koordinatı paylaşmayan ama “çok yakın” düğümler arası kısa walk ekle
    //    (ör: karşı kaldırım) — ceza uygulanacak.
    //    Basit O(N^2) pahalı; local spatial hash ile kaba azaltalım.
    final cellSize = 0.0003; // yaklaşık 30m
    final buckets = <String, List<int>>{};
    String _cellKey(LatLng p) =>
        '${(p.latitude / cellSize).floor()}:${(p.longitude / cellSize).floor()}';

    for (var i = 0; i < nodes.length; i++) {
      final k = _cellKey(nodes[i]);
      (buckets[k] ??= []).add(i);
    }

    final neighborCells = [
      const Point(0, 0),
      const Point(1, 0),
      const Point(-1, 0),
      const Point(0, 1),
      const Point(0, -1),
      const Point(1, 1),
      const Point(1, -1),
      const Point(-1, 1),
      const Point(-1, -1),
    ];

    for (var i = 0; i < nodes.length; i++) {
      final baseKey = _cellKey(nodes[i]);
      final baseLatLng = nodes[i];

      for (final off in neighborCells) {
        final k = _shiftKey(baseKey, off);
        final list = buckets[k];
        if (list == null) continue;
        for (final j in list) {
          if (j == i) continue;
          final d = _haversine(baseLatLng, nodes[j]);
          if (d <= transferRadiusMeters) {
            _addEdge(i, j, d, 'walk', bidir: true);
          }
        }
      }
    }
  }

  String _shiftKey(String base, Point<int> off) {
    final parts = base.split(':');
    final r = int.parse(parts[0]) + off.x;
    final c = int.parse(parts[1]) + off.y;
    return '$r:$c';
  }

  // En yakın gerçek node (stop)
  int? nearestNode(LatLng p) {
    if (nodes.isEmpty) return null;
    var best = 0;
    var bestD = _haversine(p, nodes[0]);
    for (var i = 1; i < nodes.length; i++) {
      final d = _haversine(p, nodes[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  // Bu node’u hangi hatlar kullanıyor?
  Set<String> linesOfNode(int id) => nodeLines[id] ?? <String>{};

  // Portal: sadece start/end için yakın duraklara yürüyüş kenarı
  int addPortal(LatLng p, {required double maxWalk, int kNearest = 6}) {
    final portalId = nodes.length;
    nodes.add(p);
    adj.add(<_Edge>[]);

    // kaba en yakın K node
    final cand = <_Near>[];
    for (var i = 0; i < nodes.length - 1; i++) {
      final d = _haversine(p, nodes[i]);
      if (d <= maxWalk) cand.add(_Near(id: i, d: d));
    }
    cand.sort((a, b) => a.d.compareTo(b.d));
    final pick = cand.take(kNearest);

    for (final c in pick) {
      _addEdge(portalId, c.id, c.d, 'walk', bidir: true);
    }
    return portalId;
  }

  // Tek seferlik (direct check sırasında) walk polyline (straight)
  List<LatLng> _maybeWalkPortal(LatLng from, int toNode, double maxWalk) {
    final d = _haversine(from, nodes[toNode]);
    if (d > maxWalk) return const [];
    return [from, nodes[toNode]];
  }

  // Dijkstra-state: (cost, node, currentLine, transfers, parent)
  _State? _dijkstraLimitedTransfers(
    int src,
    int dst, {
    required int maxTransfers,
  }) {
    final n = nodes.length;
    final dist = List<double>.filled(n, double.infinity);
    final prev = List<int?>.filled(n, null);
    final prevEdge = List<_Edge?>.filled(n, null);
    final curLine = List<String?>.filled(n, null);
    final transfers = List<int>.filled(n, 1 << 29);

    // binary heap basit: List + sort (N log N) yeter
    final heap = <_QItem>[];

    dist[src] = 0;
    transfers[src] = 0;
    curLine[src] = null;
    heap.add(_QItem(cost: 0, id: src, line: null, transfers: 0));

    while (heap.isNotEmpty) {
      heap.sort((a, b) => a.cost.compareTo(b.cost));
      final q = heap.removeAt(0);

      if (q.id == dst) break;
      if (q.cost > dist[q.id]) continue;

      for (final e in adj[q.id]) {
        // AI cost
        final nextLine = (e.kind == 'bus')
            ? e.line
            : q.line; // yürüyüşte hat değişmez
        var nextTransfers = q.transfers;
        if (e.kind == 'bus' && q.line != null && e.line != q.line) {
          // hat değişimi
          nextTransfers = q.transfers + 1;
          if (nextTransfers > maxTransfers) continue;
        }

        final step = _aiCostMeters(e, q.line, nextTransfers);
        final nd = q.cost + step;

        if (nd + 1e-6 < dist[e.to] || nextTransfers < transfers[e.to]) {
          dist[e.to] = nd;
          prev[e.to] = q.id;
          prevEdge[e.to] = e;
          curLine[e.to] = nextLine;
          transfers[e.to] = nextTransfers;
          heap.add(
            _QItem(
              cost: nd,
              id: e.to,
              line: nextLine,
              transfers: nextTransfers,
            ),
          );
        }
      }
    }

    if (dist[dst] == double.infinity) return null;

    // path reconstruct
    final path = <int>[];
    int? v = dst;
    while (v != null) {
      path.add(v);
      v = prev[v];
    }
    path.reverse();

    return _State(
      path: path,
      total: dist[dst],
      transfers: transfers[dst],
      endLine: curLine[dst],
    );
  }

  List<RouteSegment> _nodesToSegments(List<int> path) {
    if (path.length < 2) return const [];

    final segs = <RouteSegment>[];

    String? curKind;
    String? curLine;
    final buf = <LatLng>[];

    void flush() {
      if (buf.length >= 2 && curKind != null) {
        segs.add(
          RouteSegment(kind: curKind!, line: curLine, points: List.of(buf)),
        );
      }
      buf.clear();
    }

    // İlk noktayı al
    buf.add(nodeLatLng(path.first));
    // Edge’leri gez
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i], b = path[i + 1];
      final e = _edgeBetween(a, b);
      if (e == null) continue;
      final k = e.kind;
      final l = e.line;

      final change = (curKind != k) || (k == 'bus' && curLine != l);

      if (change) {
        flush();
        curKind = k;
        curLine = (k == 'bus') ? l : null;
        buf.add(nodeLatLng(a));
      }
      buf.add(nodeLatLng(b));
    }
    flush();

    // Segmentleri gereksiz tek-nokta olanları temizle
    return segs.where((s) => s.points.length >= 2).toList();
  }

  _Edge? _edgeBetween(int a, int b) {
    for (final e in adj[a]) {
      if (e.to == b) return e;
    }
    return null;
  }

  LatLng nodeLatLng(int id) => nodes[id];
}

/// ======================
/// AI cost / helpers
/// ======================

double _aiCostMeters(_Edge e, String? prevLine, int transfers) {
  // temel: mesafe
  double w = e.w;

  if (e.kind == 'bus') {
    // ör: bazı hat öncelikleri: K- hatları biraz teşvik
    if ((e.line ?? '').startsWith('K')) w *= 0.92;
    if ((e.line ?? '').startsWith('G')) w *= 0.98;

    // hat değişim cezası: transfer başına +%20
    if (prevLine != null && e.line != prevLine) {
      w *= (1.20 + 0.05 * min(transfers, 3)); // az artan ek çarpan
    }
  } else {
    // walk -> biraz daha pahalı yap; gereksiz yürüyüşe kaçmasın
    w *= 1.10;
  }

  return w;
}

double _haversine(LatLng a, LatLng b) {
  const R = 6371000.0;
  final phi1 = a.latitude * pi / 180.0;
  final phi2 = b.latitude * pi / 180.0;
  final dphi = (b.latitude - a.latitude) * pi / 180.0;
  final dl = (b.longitude - a.longitude) * pi / 180.0;
  final h =
      sin(dphi / 2) * sin(dphi / 2) +
      cos(phi1) * cos(phi2) * sin(dl / 2) * sin(dl / 2);
  return 2 * R * atan2(sqrt(h), sqrt(1 - h));
}

double _polylineMeters(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  var s = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    s += _haversine(pts[i], pts[i + 1]);
  }
  return s;
}

double _sumMeters(List<RouteSegment> segs) =>
    segs.fold<double>(0, (sum, s) => sum + _polylineMeters(s.points));

int _countTransfers(List<RouteSegment> segs) {
  String? lastLine;
  var t = 0;
  for (final s in segs) {
    if (s.kind != 'bus') continue;
    if (lastLine != null && s.line != lastLine) t++;
    lastLine = s.line;
  }
  return t;
}

class _QItem {
  final double cost;
  final int id;
  final String? line;
  final int transfers;
  _QItem({
    required this.cost,
    required this.id,
    required this.line,
    required this.transfers,
  });
}

class _Near {
  final int id;
  final double d;
  _Near({required this.id, required this.d});
}

extension _Reverse<T> on List<T> {
  void reverse() {
    int i = 0, j = length - 1;
    while (i < j) {
      final tmp = this[i];
      this[i] = this[j];
      this[j] = tmp;
      i++;
      j--;
    }
  }
}

class _State {
  final List<int> path;
  final double total;
  final int transfers;
  final String? endLine;

  _State({
    required this.path,
    required this.total,
    required this.transfers,
    required this.endLine,
  });
}
