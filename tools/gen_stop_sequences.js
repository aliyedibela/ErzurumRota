const fs = require('fs');
const content = fs.readFileSync('lib/data/generated_polylines.dart.bak', 'utf-8');
const newContent = content.replace(/final List<LatLng> (\w+)/g, 'final List<LatLng> stops_$1');
fs.writeFileSync('lib/data/bus_stop_sequences.dart', newContent, 'utf-8');
console.log('Yazildi: lib/data/bus_stop_sequences.dart');
console.log('Satir sayisi:', newContent.split('\n').length);
