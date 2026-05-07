// generate_polylines.js
// Mevcut generated_polylines.dart dosyasını okur,
// her rota için OSRM'den gercek yol geometrisi alir
// ve yeni bir generated_polylines.dart olusturur.

const fs = require('fs');
const path = require('path');

const OSRM_BASE = 'https://router.project-osrm.org';
const DART_FILE = path.join(__dirname, '..', 'lib', 'data', 'generated_polylines.dart');
const DELAY_MS = 600; // her istek arasi bekleme (ms)

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function getRoadGeometry(stops) {
  if (stops.length < 2) return stops;

  // OSRM: lng,lat;lng,lat;...
  const coords = stops.map(([lat, lng]) => `${lng},${lat}`).join(';');
  const url = `${OSRM_BASE}/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=false`;

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) {
      console.log(`  HTTP ${res.status}, falling back to straight lines`);
      return stops;
    }
    const data = await res.json();
    if (data.code !== 'Ok') {
      console.log(`  OSRM code: ${data.code}, falling back`);
      return stops;
    }
    // GeoJSON koordinatlari [lng, lat] formatinda gelir, biz [lat, lng] istiyoruz
    return data.routes[0].geometry.coordinates.map(([lng, lat]) => [lat, lng]);
  } catch (err) {
    console.log(`  Hata: ${err.message}, falling back`);
    return stops;
  }
}

function parseDartFile(content) {
  const results = [];
  // final List<LatLng> VARNAME = [ ... ];
  const blockRegex = /final List<LatLng> (\w+)\s*=\s*\[([\s\S]*?)\];/g;
  const latlngRegex = /LatLng\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)/g;

  let blockMatch;
  while ((blockMatch = blockRegex.exec(content)) !== null) {
    const varname = blockMatch[1];
    const body = blockMatch[2];
    const stops = [];
    let lm;
    while ((lm = latlngRegex.exec(body)) !== null) {
      stops.push([parseFloat(lm[1]), parseFloat(lm[2])]);
    }
    results.push({ varname, stops });
  }
  return results;
}

function formatNumber(n) {
  // Dart'ta virgulden sonra en az 1, en fazla 10 hane
  const s = n.toFixed(10).replace(/\.?0+$/, '');
  return s.includes('.') ? s : s + '.0';
}

function generateDartFile(varDataList) {
  let out = "import 'package:latlong2/latlong.dart';\n";
  for (const { varname, stops } of varDataList) {
    out += `\nfinal List<LatLng> ${varname} = [\n`;
    for (const [lat, lng] of stops) {
      out += `  LatLng(${formatNumber(lat)}, ${formatNumber(lng)}),\n`;
    }
    out += '];\n';
  }
  return out;
}

async function main() {
  console.log('Dart dosyasi okunuyor...');
  const content = fs.readFileSync(DART_FILE, 'utf-8');
  const varList = parseDartFile(content);
  console.log(`${varList.length} polyline degiskeni bulundu.\n`);

  // Yedek al
  fs.writeFileSync(DART_FILE + '.bak', content, 'utf-8');
  console.log(`Yedek: ${DART_FILE}.bak\n`);

  const enriched = [];
  for (let i = 0; i < varList.length; i++) {
    const { varname, stops } = varList[i];
    process.stdout.write(`[${i + 1}/${varList.length}] ${varname} (${stops.length} durak)... `);

    if (stops.length < 2) {
      console.log('atlandi (az durak)');
      enriched.push({ varname, stops });
      continue;
    }

    const roadStops = await getRoadGeometry(stops);
    console.log(`-> ${roadStops.length} yol noktasi`);
    enriched.push({ varname, stops: roadStops });

    await sleep(DELAY_MS);
  }

  console.log('\nYeni Dart dosyasi yaziliyor...');
  const newContent = generateDartFile(enriched);
  fs.writeFileSync(DART_FILE, newContent, 'utf-8');
  console.log('Tamamlandi! generated_polylines.dart guncellendi.');
}

main().catch(err => {
  console.error('Script hatasi:', err);
  process.exit(1);
});
