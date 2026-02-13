const fs = require("fs");

// 📁 1️⃣ Metin dosyasının yolu
const filePath = "data.txt";

// 📖 2️⃣ Dosyayı oku
const text = fs.readFileSync(filePath, "utf8");

// 🧠 3️⃣ Satır başındaki 5 haneli kodları yakala
const lines = text.split(/\r?\n/);
const codes = [];

for (const line of lines) {
  const match = line.match(/^(\d{5})/);
  if (match) codes.push(match[1]);
}

// 🧾 4️⃣ Kodları virgülle ayır
const output = codes.join(", ");

// 💾 5️⃣ Dosyaya yaz
fs.writeFileSync("codes.txt", output);

// 📢 6️⃣ Konsola da bastır
console.log("✅ Kodlar başarıyla alındı!");
console.log("Toplam Kod:", codes.length);
console.log(output);
