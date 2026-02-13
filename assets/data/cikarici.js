const fs = require("fs");

// JSON'u dosyadan oku
const allStops = JSON.parse(fs.readFileSync("./all_stops.json", "utf8"));

if (!fs.existsSync("./all_stops.json")) {
  console.error("❌ all_stops.json bulunamadı, dosya doğru dizinde mi?");
  process.exit(1);
}


// 🔥 tüm hat adlarını topla (benzersiz)
const hatlar = [...new Set(allStops.flatMap(s => s.routes))];

const hatPolylines = {};

for (const hat of hatlar) {
      console.log("⏳ işleniyor:", hat);
  // bu hattın geçtiği durakları sırayla al
  const duraklar = allStops
    .filter(s => s.routes.includes(hat))
    .map(s => ({
      lat: parseFloat(s.lat),
      lng: parseFloat(s.lng),
      name: s.stopName,
      id: s.stopId
    }));

  if (duraklar.length === 0) continue;

  // 🔹 normal polyline
  const dogru = duraklar.map(d => `LatLng(${d.lat}, ${d.lng})`);

  // 🔹 ters polyline
  const ters = [...duraklar].reverse().map(d => `LatLng(${d.lat}, ${d.lng})`);

  hatPolylines[`${hat}Dogru`] = dogru;
  hatPolylines[`${hat}Ters`] = ters;
}

// 🔸 Dart kodu olarak çıktı ver
let dartOutput = "";
for (const [key, coords] of Object.entries(hatPolylines)) {
  dartOutput += `final List<LatLng> ${key} = [\n  ${coords.join(",\n  ")}\n];\n\n`;
}

fs.writeFileSync("generated_polylines.dart", dartOutput);
console.log("✅ Tüm hat polyline'ları 'generated_polylines.dart' dosyasına yazıldı!");
