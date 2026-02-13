const fs = require("fs");
const path = require("path");

// === Dosya yolu ===
const FILE_PATH = path.join(__dirname, "all_stops.txt");

// === Hedef durak ID’leri ===
const stopIds = [
20242, 20167, 20170, 20171, 20172, 20174, 20175, 20176, 20177, 20229, 20240, 20208, 20215, 20216, 20218, 20219, 20220, 20221, 20180, 20181, 20182, 20183, 20184, 20096, 20097, 20098, 20099, 20100, 20101, 20102, 20005, 20006, 20007, 20008, 20009, 20010, 20011, 20012, 20013, 20014, 20015, 20017, 20019, 20020, 30180, 30183, 30184, 30185, 30189, 30191, 30193, 30194, 30195, 30196, 30197, 30065, 30067, 30068, 30070, 30072, 30074, 30076, 30077, 30078, 30080, 30081, 30087, 30085, 30088, 30094, 30201, 30202, 30203, 30207, 30206, 30208, 30210, 30192, 30190, 30186, 30187, 30188, 30182, 30181, 20021, 20022, 20023, 20127, 20073, 20074, 20076, 20077, 20078, 20079, 20080, 20083, 20084, 20085, 20086, 20087, 20088, 20089, 20090, 20185, 20186, 20187, 20188, 20198, 20223, 20224, 20225, 20229, 20162, 20191, 20192, 20193, 20194, 20195, 20196, 20248
];

// === Fonksiyonlar ===

// Her satırdan id, lat, lng çıkarır
function parseAllStops(text) {
  const map = new Map();
  const lines = text.split(/\r?\n/);

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;

    const idMatch = line.match(/^(\d{5,})\b/);
    if (!idMatch) continue;
    const id = idMatch[1];

    // 🔍 Koordinat formatına tam uyan desen: 39.xxxx 41.xxxx gibi
    const coordMatch = line.match(
      /\b(3[6-9]\.\d{4,8})\D+(4[0-3]\.\d{4,8})\b/
    );

    if (coordMatch) {
      const lat = parseFloat(coordMatch[1]);
      const lng = parseFloat(coordMatch[2]);
      if (lat >= 38 && lat <= 42.5 && lng >= 39 && lng <= 44) {
        map.set(id, { lat, lng });
      }
    }
  }
  return map;
}

function buildDartList(routeName, ids, map) {
  const coords = [];
  const missing = [];

  for (const id of ids) {
    const s = String(id);
    const c = map.get(s);
    if (c) coords.push(c);
    else missing.push(s);
  }

  const body = coords.map((c) => `  LatLng(${c.lat}, ${c.lng}),`).join("\n");
  const dart = `final List<LatLng> ${routeName} = [\n${body}\n];`;

  console.log(dart);

  if (missing.length)
    console.warn("\n⚠️ Eşleşmeyen ID'ler:", missing.join(", "));
}

// === Çalıştır ===
const text = fs.readFileSync(FILE_PATH, "utf8");
const map = parseAllStops(text);
buildDartList("G6_Gidis", stopIds, map);
