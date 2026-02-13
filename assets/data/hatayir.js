const fs = require("fs");

// === 1️⃣ Verini buraya yapıştır ===
const K7DogruRaw = `
LatLng(39.8927462, 41.2008754),
  LatLng(39.8985267, 41.1998618),
  LatLng(39.9006245, 41.1986669),
  LatLng(39.9025095, 41.1981318),
  LatLng(39.9048573, 41.197535),
  LatLng(39.9066949, 41.1967257),
  LatLng(39.9094151, 41.1950053),
  LatLng(39.9118695, 41.1936236),
  LatLng(39.9131921, 41.1926731),
  LatLng(39.9147078, 41.1914078),
  LatLng(39.9160422, 41.1902414),
  LatLng(39.91768, 41.188787),
  LatLng(39.9215911, 41.1879575),
  LatLng(39.9225566, 41.1892848),
  LatLng(39.9205644, 41.1970173),
  LatLng(39.9192671, 41.2017273),
  LatLng(39.9186389, 41.2040709),
  LatLng(39.9134391, 41.2237312),
  LatLng(39.9116522, 41.230432),
  LatLng(39.9107458, 41.2340295),
  LatLng(39.909128, 41.239285),
  LatLng(39.9051316, 41.255022),
  LatLng(39.9050009, 41.2607957),
  LatLng(39.9052286, 41.2633791),
  LatLng(39.907108, 41.265837),
  LatLng(39.909519, 41.265499),
  LatLng(39.9117262, 41.2657996),
  LatLng(39.91311, 41.2709922),
  LatLng(39.9114485, 41.272678),
  LatLng(39.9068743, 41.2734512),
  LatLng(39.9022003, 41.2745693),
  LatLng(39.9008496, 41.2756235),
  LatLng(39.9008319, 41.278347),
  LatLng(39.9008559, 41.281117),
  LatLng(39.9032544, 41.2834293),
  LatLng(39.9050458, 41.2854363),
  LatLng(39.90592, 41.288536),
  LatLng(39.9053339, 41.2904531),
  LatLng(39.9027498, 41.2893507),
  LatLng(39.9013969, 41.2875335),
  LatLng(39.900274, 41.2859591),
  LatLng(39.8991409, 41.2844061),
  LatLng(39.8974092, 41.2807642),
  LatLng(39.8969821, 41.2787124),
  LatLng(39.898671, 41.275536),
  LatLng(39.902265, 41.274811),
  LatLng(39.905258, 41.273859),
  LatLng(39.9069442, 41.2737781),
  LatLng(39.9074883, 41.2735957),
  LatLng(39.91188, 41.272755),
  LatLng(39.913412, 41.270115),
  LatLng(39.912086, 41.266279),
  LatLng(39.909434, 41.265108),
  LatLng(39.907129, 41.265455),
  LatLng(39.905586, 41.264115),
  LatLng(39.905322, 41.260757),
  LatLng(39.905496, 41.255155),
  LatLng(39.909808, 41.238893),
  LatLng(39.9110818, 41.2339027),
  LatLng(39.9120387, 41.2302301),
  LatLng(39.9138181, 41.2235397),
  LatLng(39.9190076, 41.2042331),
  LatLng(39.9217174, 41.1938594),
  LatLng(39.9228999, 41.189532),
  LatLng(39.9219068, 41.187862),
  LatLng(39.919632, 41.1867622),
  LatLng(39.9158025, 41.1901438),
  LatLng(39.9147577, 41.1909371),
  LatLng(39.912773, 41.1925749),
  LatLng(39.911286, 41.1935979),
  LatLng(39.9085773, 41.1951344),
  LatLng(39.9069256, 41.1961831),
  LatLng(39.9050911, 41.1971022),
  LatLng(39.9024169, 41.1977747),
`;

// === 2️⃣ Metinden sadece sayı çiftlerini ayıklıyoruz ===
const K7Dogru = Array.from(K7DogruRaw.matchAll(/LatLng\(([^,]+),\s*([^)]+)\)/g)).map(m => [
  parseFloat(m[1]), parseFloat(m[2])
]);

// === 3️⃣ Haversine formülü (metre cinsinden mesafe)
function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = x => (x * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// === 4️⃣ Ortalama adım uzunluğunu bul
const stepDistances = [];
for (let i = 1; i < K7Dogru.length; i++) {
  stepDistances.push(
    haversine(
      K7Dogru[i - 1][0], K7Dogru[i - 1][1],
      K7Dogru[i][0], K7Dogru[i][1]
    )
  );
}
const avgDist = stepDistances.reduce((a, b) => a + b, 0) / stepDistances.length;

// === 5️⃣ Ani dönüş (geri yön) tespiti
let splitIndex = 0;
for (let i = 10; i < K7Dogru.length - 10; i++) {
  const d = haversine(
    K7Dogru[i][0], K7Dogru[i][1],
    K7Dogru[i + 10][0], K7Dogru[i + 10][1]
  );
  if (d < avgDist * 2) {
    splitIndex = i;
    break;
  }
}

// === 6️⃣ Çıktı oluştur
if (splitIndex > 0) {
  const K7Gidis = K7Dogru.slice(0, splitIndex);
  const K7Donus = K7Dogru.slice(splitIndex);

  const format = arr =>
    arr.map(([lat, lon]) => `LatLng(${lat}, ${lon}),`).join("\n");

  const output = `
📍 K7Gidis (${K7Gidis.length} nokta)
${format(K7Gidis)}

📍 K7Donus (${K7Donus.length} nokta)
${format(K7Donus)}
`;

  console.log(output);
  fs.writeFileSync("K7_split.txt", output);
  console.log("\n✅ Sonuç 'K7_split.txt' dosyasına kaydedildi.");
} else {
  console.log("⚠️ Otomatik dönüş noktası tespit edilemedi.");
}
