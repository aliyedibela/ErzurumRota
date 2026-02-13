// ==========================
// Erzurum Hat JSON Exporter
// ==========================

import fs from "fs";

// 1️⃣ Kaynak dosyanın yolunu belirt (örnek: generated_polylines.dart)
const inputFile = "./generated_polylines.dart";
const outputFile = "./bus_lines.json";

// 2️⃣ Dosyayı oku
const dartContent = fs.readFileSync(inputFile, "utf8");

// 3️⃣ Regex ile tüm hat bloklarını yakala
const regex =
  /final\s+List<LatLng>\s+([A-Za-z0-9_]+)\s*=\s*\[(.*?)\];/gs;

const lines = {};
let match;

while ((match = regex.exec(dartContent)) !== null) {
  const lineName = match[1]; // örn: K6Dogru
  const body = match[2];

  // 4️⃣ LatLng(...) yapılarını bul
  const coords = [...body.matchAll(/LatLng\(([^,]+),\s*([^)]+)\)/g)].map(
    (m) => [parseFloat(m[1]), parseFloat(m[2])]
  );

  if (coords.length > 0) {
    // Hattın ana ismini çıkar (örnek: "K6Dogru" → "K6")
    const cleanName = lineName.replace(/Dogru|Donus|A$/gi, "");
    lines[cleanName] = {
      line: cleanName,
      stops: coords,
    };
  }
}

// 5️⃣ JSON olarak kaydet
fs.writeFileSync(outputFile, JSON.stringify(lines, null, 2), "utf8");

console.log(
  `✅ ${Object.keys(lines).length} hat başarıyla dışa aktarıldı → ${outputFile}`
);
