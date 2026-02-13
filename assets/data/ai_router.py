import json, math
from collections import defaultdict, namedtuple
from heapq import heappush, heappop

# =========================
# 1) Yardımcılar
# =========================
def haversine(a, b):
    R = 6371000.0
    (lat1, lon1), (lat2, lon2) = a, b
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi   = math.radians(lat2 - lat1)
    dlamb  = math.radians(lon2 - lon1)
    x = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlamb/2)**2
    return 2 * R * math.atan2(math.sqrt(x), math.sqrt(1-x))

def near(a, b, tol_m=25):
    return haversine(a, b) <= tol_m

# =========================
# 2) Veri oku
# bus_lines.json beklenen biçim:
# {
#   "K7": {"stops": [[lat,lon], [lat,lon], ...]},
#   "B3": {"stops": [...]},
#   ...
# }
# =========================
with open("bus_lines.json", "r", encoding="utf-8") as f:
    RAW = json.load(f)

# =========================
# 3) Duran noktaları kümele (aynı fizikî durak = tek node)
#    - Aynı konum veya 25 m'den yakın noktalar birleştirilir.
# =========================
cluster_tol = 25  # metre
nodes = []        # [(lat, lon)]
node_id_of = {}   # (lat,lon) -> cluster id
def assign_node_id(pt):
    # mevcut cluster'a yakınsa ona ata
    for idx, cpt in enumerate(nodes):
        if near(pt, cpt, cluster_tol):
            return idx
    # değilse yeni cluster
    nodes.append(pt)
    return len(nodes)-1

# Hat -> node_id dizisi
line_nodes = {}
for line, obj in RAW.items():
    ids = []
    for lat, lon in obj["stops"]:
        nid = assign_node_id((lat, lon))
        ids.append(nid)
    line_nodes[line] = ids

# =========================
# 4) Graph inşa
#    - hat içi ardışık node'lar (iki yön)
#    - hatlar arası aktarma: aynı node üzerinde (cluster sayesinde otomatik)
#    - yürüme: start/end -> yakındaki node'lar
# =========================
Edge = namedtuple("Edge", "to cost kind meta")  # kind: "bus"|"walk", meta: {"line": str}|None
graph = defaultdict(list)

# hat içi bağlantılar
for line, nlist in line_nodes.items():
    for i in range(len(nlist)-1):
        a, b = nlist[i], nlist[i+1]
        pa, pb = nodes[a], nodes[b]
        d = haversine(pa, pb)
        # ileri-geri iki yön
        graph[a].append(Edge(b, d, "bus", {"line": line, "step": (i, i+1)}))
        graph[b].append(Edge(a, d, "bus", {"line": line, "step": (i+1, i)}))

# Aynı fizikî node üzerinde aktarma için ek kenar koymaya gerek yok:
# clusterlama sayesinde "aynı node id" üzerinde zaten hat değişimi yapılabilir.
# Ama maliyet fonksiyonu içinde "line change" = transfer olarak cezalandıracağız.

# =========================
# 5) AI maliyet fonksiyonu
# =========================
class Weights:
    WALK_PER_M = 1.15      # yürüyüş 1.15x (otobüse göre pahalı)
    BUS_PER_M  = 1.00
    TRANSFER_PENALTY = 240 # her hat değişiminde sabit ceza (metre eşdeğeri)
    BACKTRACK_PENALTY = 1.10  # geri yönde gitme eğilimine küçük çarpan
    LONG_PATH_CURVE  = 1.00004 # her kenarda kümülatif çarpan (çok dolaşıma artan ceza)

def ai_incremental_cost(edge, prev_line, progressed, cumulative_cost):
    """
    edge: Edge
    prev_line: önceki hattın adı veya None
    progressed: +1/-1/0 (hattın doğal dizilişi boyunca gidiyor mu) — yoksa 0
    cumulative_cost: şu ana kadarki biriken cost
    """
    if edge.kind == "walk":
        base = edge.cost * Weights.WALK_PER_M
        line_change_penalty = 0
    else:
        base = edge.cost * Weights.BUS_PER_M
        line_change_penalty = (Weights.TRANSFER_PENALTY
                               if prev_line is not None and edge.meta["line"] != prev_line
                               else 0)
        backtrack = (Weights.BACKTRACK_PENALTY if progressed < 0 else 1.0)
        base *= backtrack

    # uzun dolaşıma hafif, kümülatif artan ceza
    curve = (Weights.LONG_PATH_CURVE ** (cumulative_cost / 10.0))
    return base * curve + line_change_penalty

# =========================
# 6) Start/End -> yakın node'lara yürüyüş kenarları
# =========================
def nearby_nodes(pt, radius=600, k=12):
    # en yakın k node'u bul, radius içinde olanları döndür
    dists = []
    for i, npt in enumerate(nodes):
        d = haversine(pt, npt)
        if d <= radius:
            dists.append((d, i))
    dists.sort()
    return dists[:k]

def add_walk_portals_for_point(pt):
    portal_id = len(nodes)  # sanal node
    nodes.append(pt)
    # graph'a yer aç
    _ = graph[portal_id]
    for d, nid in nearby_nodes(pt):
        graph[portal_id].append(Edge(nid, d, "walk", None))
        graph[nid].append(Edge(portal_id, d, "walk", None))
    return portal_id

# =========================
# 7) Dijkstra (segmente ayrılmış yol)
# =========================
def best_path_segments(start_ll, end_ll):
    start_id = add_walk_portals_for_point(tuple(start_ll))
    end_id   = add_walk_portals_for_point(tuple(end_ll))

    # (cost, node, prev_line, came_from, cum_cost, stepdir_hint)
    # stepdir_hint: node->next geçişte "hat dizilişi yönünde mi?" sinyali için (index farkından çıkaracağız)
    pq = []
    heappush(pq, (0.0, start_id, None, None, 0.0))
    visited_cost = {start_id: 0.0}
    parent = {}  # node -> (prev_node, Edge, prev_line, cum_cost)

    # hat içi ilerleme yönünü tahmin etmek için: node_id -> line -> index
    # (bir node bir hattan birden fazla kez geçiyorsa en küçük index’i tutmak yeterli)
    line_index = defaultdict(dict)  # node -> {line: min_index}
    for line, nlist in line_nodes.items():
        for idx, nid in enumerate(nlist):
            if line not in line_index[nid]:
                line_index[nid][line] = idx
            else:
                line_index[nid][line] = min(line_index[nid][line], idx)

    while pq:
        cost, u, prev_line, _, cum = heappop(pq)
        if cost != visited_cost.get(u, float("inf")):
            continue
        if u == end_id:
            break

        for e in graph[u]:
            v = e.to
            # ilerleme yönü sinyali (sadece bus için)
            progressed = 0
            if e.kind == "bus":
                line = e.meta["line"]
                if line in line_index.get(u, {}) and line in line_index.get(v, {}):
                    i_u = line_index[u][line]
                    i_v = line_index[v][line]
                    if i_v > i_u:
                        progressed = +1
                    elif i_v < i_u:
                        progressed = -1

            inc = ai_incremental_cost(e, prev_line, progressed, cum)
            ncost = cost + inc
            if ncost < visited_cost.get(v, float("inf")):
                visited_cost[v] = ncost
                parent[v] = (u, e, prev_line, cum)
                nline = e.meta["line"] if e.kind == "bus" else prev_line
                heappush(pq, (ncost, v, nline, u, cum + (e.cost if e.kind=="bus" else 0)))

    if end_id not in parent:
        return []  # yol yok

    # geri izleme
    path_edges = []
    cur = end_id
    while cur != start_id:
        pu, e, prev_line, prev_cum = parent[cur]
        path_edges.append((pu, cur, e))
        cur = pu
    path_edges.reverse()

    # segmentlere böl (walk/bus line)
    segments = []
    cur_kind = None
    cur_line = None
    buf = []

    def flush():
        nonlocal buf, cur_kind, cur_line
        if not buf:
            return
        seg = {
            "kind": cur_kind,
            "line": cur_line if cur_kind == "bus" else None,
            "coords": [nodes[nid] for nid in buf]
        }
        segments.append(seg)
        buf = []

    # node zinciri üret
    chain = [start_id] + [v for _, v, _ in path_edges]
    # edge türleri üzerinden segment topla
    for i in range(len(path_edges)):
        u, v, e = path_edges[i]
        kind = e.kind
        line = e.meta["line"] if kind == "bus" else None
        # segment değişti mi?
        if kind != cur_kind or (kind == "bus" and line != cur_line):
            flush()
            cur_kind, cur_line = kind, line
            buf = [u, v]
        else:
            buf.append(v)
    flush()

    # start/end portalları temizle
    # (ilk/son segmentte portal node’u gelebilir; koordinatları gerçek yürüme yolunda snap’lerken zaten OSRM kullanıyorsun)
    def drop_portals(seg):
        coords = [c for c in seg["coords"] if c != tuple(start_ll) and c != tuple(end_ll)]
        if not coords:
            coords = seg["coords"]
        return {**seg, "coords": coords}

    segments = [drop_portals(s) for s in segments]

    return segments

# =========================
# 8) Örnek kullanım
# =========================
if __name__ == "__main__":
    start = (39.905975, 41.256332)
    end   = (39.951605, 41.310482)
    segs = best_path_segments(start, end)
    if not segs:
        print("⚠️ Yol bulunamadı.")
    else:
        print(f"✅ {len(segs)} segment:")
        for s in segs:
            label = "Yürüyüş" if s["kind"]=="walk" else f"Otobüs ({s['line']})"
            print(f" - {label}: {len(s['coords'])} nokta")
