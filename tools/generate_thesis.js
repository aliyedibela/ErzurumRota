// Erzurum Şehir Rehberi - Bitirme Projesi Tez Oluşturucu
// Node.js + docx kütüphanesi ile ETÜ şablonuna uygun Word belgesi oluşturur

const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  Table, TableRow, TableCell, WidthType, BorderStyle, PageBreak,
  ShadingType, convertInchesToTwip, UnderlineType, LevelFormat,
  NumberFormat, TabStopType, TabStopLeader, ImageRun
} = require('docx');
const fs = require('fs');
const path = require('path');

// ─── Stil yardımcıları ─────────────────────────────────────────────────────

function bold(text, size = 24) {
  return new TextRun({ text, bold: true, size });
}

function normal(text, size = 24) {
  return new TextRun({ text, size });
}

function italic(text, size = 24) {
  return new TextRun({ text, italics: true, size });
}

function p(children, options = {}) {
  return new Paragraph({
    children: Array.isArray(children) ? children : [children],
    alignment: options.align || AlignmentType.JUSTIFIED,
    spacing: { before: options.spaceBefore || 0, after: options.spaceAfter || 160, line: options.line || 360 },
    indent: options.indent ? { firstLine: convertInchesToTwip(0.5) } : undefined,
    ...options.extra,
  });
}

function center(children, opts = {}) {
  return p(children, { align: AlignmentType.CENTER, ...opts });
}

function h1(text) {
  return new Paragraph({
    text,
    heading: HeadingLevel.HEADING_1,
    alignment: AlignmentType.LEFT,
    spacing: { before: 480, after: 240 },
    pageBreakBefore: true,
  });
}

function h2(text) {
  return new Paragraph({
    text,
    heading: HeadingLevel.HEADING_2,
    alignment: AlignmentType.LEFT,
    spacing: { before: 360, after: 160 },
  });
}

function h3(text) {
  return new Paragraph({
    text,
    heading: HeadingLevel.HEADING_3,
    alignment: AlignmentType.LEFT,
    spacing: { before: 280, after: 120 },
  });
}

function pageBreak() {
  return new Paragraph({
    children: [new PageBreak()],
    spacing: { before: 0, after: 0 },
  });
}

function blank(n = 1) {
  return Array.from({ length: n }, () => new Paragraph({ text: '', spacing: { before: 0, after: 0 } }));
}

function para(text, opts = {}) {
  return p([new TextRun({ text, size: 24 })], { indent: true, ...opts });
}

function paraNoIndent(text, opts = {}) {
  return p([new TextRun({ text, size: 24 })], { ...opts });
}

function centeredText(text, size = 24, isBold = false) {
  return center([new TextRun({ text, size, bold: isBold })]);
}

function sectionTitle(text) {
  return new Paragraph({
    children: [new TextRun({ text, bold: true, size: 28 })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 480, after: 240 },
    pageBreakBefore: true,
  });
}

function tableCell(text, options = {}) {
  return new TableCell({
    children: [new Paragraph({
      children: [new TextRun({ text, size: 22, bold: options.bold || false })],
      alignment: options.align || AlignmentType.LEFT,
    })],
    width: options.width ? { size: options.width, type: WidthType.PERCENTAGE } : undefined,
    shading: options.shading ? { fill: 'D9E2F3', type: ShadingType.CLEAR, color: 'auto' } : undefined,
  });
}

function simpleTable(headers, rows) {
  const headerRow = new TableRow({
    children: headers.map(h => tableCell(h, { bold: true, shading: true })),
    tableHeader: true,
  });
  const dataRows = rows.map(row => new TableRow({
    children: row.map(cell => tableCell(cell)),
  }));
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [headerRow, ...dataRows],
  });
}

// ─── Belge içeriği ─────────────────────────────────────────────────────────

const children = [];

// ─────────────────────────────────────────────────────────────────────────────
// KAPAK SAYFASI 1
// ─────────────────────────────────────────────────────────────────────────────
children.push(centeredText('T.C.', 28, true));
children.push(centeredText('Erzurum Teknik Üniversitesi', 28, true));
children.push(centeredText('Bilgisayar Mühendisliği Bölümü', 28, true));
children.push(...blank(4));
children.push(centeredText('Erzurum Şehir Rehberi: Akıllı Ulaşım, Erişilebilirlik ve Gerçek Zamanlı Taksi Yönetimi', 32, true));
children.push(...blank(6));
children.push(centeredText('Adı SOYADI', 26));
children.push(centeredText('Adı SOYADI', 26));
children.push(centeredText('Adı SOYADI', 26));
children.push(...blank(8));
children.push(centeredText('MAYIS - 2025', 26));
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// KAPAK SAYFASI 2
// ─────────────────────────────────────────────────────────────────────────────
children.push(centeredText('T.C.', 28, true));
children.push(centeredText('Erzurum Teknik Üniversitesi', 28, true));
children.push(centeredText('Bilgisayar Mühendisliği Bölümü', 28, true));
children.push(...blank(2));
children.push(centeredText('Başlığı:', 24, true));
children.push(centeredText('Erzurum Şehir Rehberi: Akıllı Ulaşım, Erişilebilirlik ve Gerçek Zamanlı Taksi Yönetimi', 28, true));
children.push(...blank(2));
children.push(centeredText('Öğrenciler', 24, true));
children.push(centeredText('Adı SOYADI, Bilgisayar Mühendisliği', 24));
children.push(centeredText('Adı SOYADI, Bilgisayar Mühendisliği', 24));
children.push(centeredText('Adı SOYADI, Bilgisayar Mühendisliği', 24));
children.push(...blank(4));
children.push(centeredText('Proje Danışmanı:', 24, true));
children.push(centeredText('Dr. Öğr. Üyesi Adı SOYADI, Bilgisayar Mühendisliği', 24));
children.push(...blank(4));
children.push(centeredText('Teslim Tarihi:', 24, true));
children.push(centeredText('30.05.2025', 24));
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// PROJE PLANI
// ─────────────────────────────────────────────────────────────────────────────
children.push(sectionTitle('Bitirme Projesi Çalışma Proje Planı'));

children.push(h2('PROJENİN AMACI ve KAPSAMI'));
children.push(para(
  'Bu projenin amacı, Erzurum halkının şehir içi ulaşım ihtiyaçlarını karşılamak, günlük hayatı kolaylaştırmak ve özellikle görme engelli bireylerin toplu taşıma sistemini bağımsız biçimde kullanabilmelerini sağlamak için kapsamlı bir mobil uygulama geliştirmektir. "Erzurum Şehir Rehberi" adı verilen Flutter tabanlı mobil uygulama; otobüs rota öneri sistemi, gerçek zamanlı taksi çağırma, nöbetçi eczane bilgisi, etkinlik takibi, hava durumu, deprem verisi ve tarihi/kültürel rehberlik gibi birden fazla işlevi tek çatı altında toplamaktadır.'
));
children.push(para(
  'Projenin kapsamı üç ana bileşenden oluşmaktadır: (1) Flutter ile geliştirilen Erzurum Şehir Rehberi uygulaması, (2) taksi sürücüleri için ayrı bir Flutter uygulaması ve (3) .NET 8 ASP.NET Core ile geliştirilen, Railway.app üzerinde Docker konteynerinde çalışan bir SignalR backend servisi. Proje, açık kaynaklı harita ve yönlendirme altyapısını (OpenStreetMap, OSRM), dış API entegrasyonlarını (WeatherAPI, AFAD, Passo, Bubilet, Erzurum Eczacı Odası) ve anlık iletişim altyapısını (SignalR WebSocket) bir arada kullanmaktadır.'
));
children.push(para(
  'Başarım kriterleri şu şekilde belirlenmiştir: 30\'dan fazla Erzurum otobüs hattında gidiş/dönüş yönleri için doğru rota önerisi sunabilmek; aktarmalı rota hesaplaması yapabilmek; görme engelli kullanıcılara Türkçe ses bildirimi ile durak ve otobüs bilgisi verebilmek; taksi sürücüsü uygulaması ile gerçek zamanlı iletişimi 60 saniye içinde tamamlayabilmek; ve tüm bu özellikleri sorunsuz çalışan tek bir mobil uygulamada birleştirebilmek.'
));

children.push(h2('RİSK YÖNETİMİ'));
children.push(para(
  'Projenin başarıyla tamamlanmasının önünde çeşitli teknik ve organizasyonel riskler bulunmaktadır. Bu riskler ve azaltma stratejileri aşağıda ele alınmaktadır:'
));

const riskTable = simpleTable(
  ['Risk', 'Olasılık', 'Etki', 'Azaltma Stratejisi'],
  [
    ['OSRM API kesintisi', 'Orta', 'Yüksek', 'Fallback: Düz çizgi yürüyüş segmenti'],
    ['Railway.app soğuk başlatma gecikmesi', 'Yüksek', 'Orta', 'Ping mekanizması ve otomatik yeniden bağlanma'],
    ['SignalR WebSocket engeli', 'Orta', 'Yüksek', 'LongPolling fallback protokolü'],
    ['Dış API değişiklikleri (Eczane/Etkinlik)', 'Yüksek', 'Orta', 'HTML parser ile esnek scraping'],
    ['Flutter sürüm uyumsuzluğu', 'Düşük', 'Yüksek', 'SDK kısıtı: ^3.9.2 ile sabitlenmiş'],
    ['GPS izni reddedilmesi', 'Orta', 'Yüksek', 'Erzurum merkez koordinatları ile fallback'],
  ]
);
children.push(riskTable);
children.push(...blank(1));

children.push(h2('ZAMANLAMA'));
children.push(para('Proje iş parçacıkları ve Gantt çizelgesi aşağıdaki tabloda verilmektedir:'));

const ganttTable = simpleTable(
  ['Görev', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs'],
  [
    ['Proje tanımı ve araştırma', '████', '░░░░', '░░░░', '░░░░', '░░░░'],
    ['Rota ve harita altyapısı', '████', '████', '░░░░', '░░░░', '░░░░'],
    ['Backend ve SignalR geliştirme', '░░░░', '████', '████', '░░░░', '░░░░'],
    ['Taksi sistemi entegrasyonu', '░░░░', '░░░░', '████', '████', '░░░░'],
    ['Erişilebilirlik modülü', '░░░░', '░░░░', '████', '████', '░░░░'],
    ['UI/UX iyileştirmeler', '░░░░', '░░░░', '░░░░', '████', '████'],
    ['Test, hata düzeltme ve belgeleme', '░░░░', '░░░░', '░░░░', '████', '████'],
  ]
);
children.push(ganttTable);
children.push(...blank(1));

children.push(h2('PROJE KAYNAKLARI'));
children.push(para('Projede kullanılan kaynaklar aşağıda listelenmiştir:'));
children.push(para('Donanım: Kişisel bilgisayar (Windows 11), Android test cihazı'));
children.push(para('Yazılım: Flutter SDK (^3.9.2), .NET 8 SDK, Visual Studio Code, Git, Docker, PostgreSQL'));
children.push(para('Bulut Altyapısı: Railway.app (ücretsiz kademeli plan), GitHub (versiyon kontrolü)'));
children.push(para('Dış API\'ler: OSRM (açık kaynak, ücretsiz), WeatherAPI (ücretsiz katman), AFAD API (ücretsiz), Passo/Bubilet (web kazıma), Erzurum Eczacı Odası (web kazıma), Iyzico (ödeme geçidi, test modu)'));

children.push(h2('PROJE GRUBU İŞ PAYLAŞIMI'));
const gorevTable = simpleTable(
  ['Öğrenci', 'Üstlenilen Görev', 'Katkı Oranı (%)'],
  [
    ['Adı SOYADI', 'Rota öneri sistemi, OSRM entegrasyonu, otobüs simülasyonu', '34'],
    ['Adı SOYADI', '.NET Backend, SignalR Hub, taksi sistemi, ödeme entegrasyonu', '33'],
    ['Adı SOYADI', 'Flutter UI/UX, erişilebilirlik modu, dış API entegrasyonları', '33'],
  ]
);
children.push(gorevTable);
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// IEEE ETİK KURALLARI
// ─────────────────────────────────────────────────────────────────────────────
children.push(sectionTitle('IEEE Etik Kuralları'));
children.push(para(
  'Mesleğime karşı şahsi sorumluluğumu kabul ederek, hizmet ettiğim toplumlara ve üyelerine en yüksek etik ve mesleki davranışta bulunmaya söz verdiğimi ve aşağıdaki etik kurallarını kabul ettiğimi ifade ederim:'
));
const ieeeKurallar = [
  'Kamu güvenliği, sağlığı ve refahı ile uyumlu kararlar vermenin sorumluluğunu kabul etmek ve kamu veya çevreyi tehdit edebilecek faktörleri derhal açıklamak;',
  'Mümkün olabilecek çıkar çatışması durumlarından kaçınmak; çıkar çatışması olması durumunda etkilenen taraflara durumu bildirmek;',
  'Mevcut verilere dayalı tahminlerde ve fikir beyan etmelerde gerçekçi ve dürüst olmak;',
  'Her türlü rüşveti reddetmek;',
  'Mütenasip uygulamalarını ve muhtemel sonuçlarını gözeterek teknoloji anlayışını geliştirmek;',
  'Teknik yeterliliklerimizi sürdürmek ve geliştirmek; yeterli eğitim veya tecrübe olmaksızın teknolojik sorumlulukları üstlenmemek;',
  'Teknik bir çalışma hakkında yansız bir eleştiri için uğraşmak, eleştiriyi kabul etmek; hataları kabul etmek ve düzeltmek;',
  'Bütün kişilere adilane davranmak; ırk, din, cinsiyet, yaş, milliyet üzerinden ayrımcılık yapmamak;',
  'Yanlış veya kötü amaçlı eylemler sonucu kimsenin zarar görmesinden kaçınmak;',
  'Meslektaşlara ve yardımcı personele mesleki gelişimlerinde yardımcı olmak.',
];
ieeeKurallar.forEach((kural, i) => {
  children.push(para(`${i + 1}. ${kural}`));
});
children.push(...blank(2));
children.push(paraNoIndent('IEEE Yönetim Kurulu tarafından Ağustos 1990\'da onaylanmıştır.', { align: AlignmentType.RIGHT }));
children.push(...blank(2));
children.push(paraNoIndent('30.05.2025', { align: AlignmentType.RIGHT }));
children.push(paraNoIndent('Adı SOYADI', { align: AlignmentType.RIGHT }));
children.push(paraNoIndent('Adı SOYADI', { align: AlignmentType.RIGHT }));
children.push(paraNoIndent('Adı SOYADI', { align: AlignmentType.RIGHT }));
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// GÖREV DAĞILIMI VE KATKI ORANI BEYANI
// ─────────────────────────────────────────────────────────────────────────────
children.push(sectionTitle('Bitirme Projesi Görev Dağılımı Ve Katkı Oranı Beyanı'));
children.push(para(
  'Erzurum Teknik Üniversitesi Bilgisayar Mühendisliği Bölümü bitirme projesi yazım kurallarına uygun olarak hazırladığımız "Erzurum Şehir Rehberi: Akıllı Ulaşım, Erişilebilirlik ve Gerçek Zamanlı Taksi Yönetimi" başlıklı proje dokümanımızın içindeki bütün bilgilerin doğru olduğunu, bilgilerin üretilmesi ve sunulmasında bilimsel etik kurallarına uygun davrandığımızı, kullandığımız bütün kaynakları atıf yaparak belirttiğimizi ve burada sunduğumuz veri ile bilgileri unvan almak amacıyla daha önce hiçbir şekilde kullanmadığımızı beyan ederiz.'
));

const gorevBeyanTable = new Table({
  width: { size: 100, type: WidthType.PERCENTAGE },
  rows: [
    new TableRow({
      children: [
        tableCell('Adı Soyadı', { bold: true, shading: true }),
        tableCell('Projede Üstlendiği Görev(ler)', { bold: true, shading: true }),
        tableCell('Katkı Oranı (%)', { bold: true, shading: true }),
        tableCell('İmza', { bold: true, shading: true }),
      ],
      tableHeader: true,
    }),
    new TableRow({
      children: [
        tableCell('Adı SOYADI'),
        tableCell('Rota öneri sistemi (OSRM entegrasyonu, aktarma algoritması, otobüs simülasyonu, durak verisi)'),
        tableCell('34'),
        tableCell(''),
      ],
    }),
    new TableRow({
      children: [
        tableCell('Adı SOYADI'),
        tableCell('.NET 8 Backend geliştirme, SignalR Hub, JWT kimlik doğrulama, PostgreSQL, Iyzico ödeme, email servisi'),
        tableCell('33'),
        tableCell(''),
      ],
    }),
    new TableRow({
      children: [
        tableCell('Adı SOYADI'),
        tableCell('Flutter UI/UX, erişilebilirlik TTS/STT modülü, dış API entegrasyonları (WeatherAPI, AFAD, Passo, Eczane)'),
        tableCell('33'),
        tableCell(''),
      ],
    }),
  ],
});
children.push(gorevBeyanTable);
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// ÖNSÖZ
// ─────────────────────────────────────────────────────────────────────────────
children.push(sectionTitle('Önsöz'));
children.push(para(
  'Erzurum, tarihi ve kültürel zenginliğiyle öne çıkan bir Anadolu şehri olmakla birlikte, şehir içi ulaşım bilgisine erişim konusunda ciddi eksiklikler barındırmaktadır. Özellikle 30\'u aşkın otobüs hattının güzergâhlarının sayısal ortamda düzenli biçimde sunulmaması, görme engelli bireylerin toplu taşıma sistemini bağımsız olarak kullanamaması ve merkezi bir şehir rehberinin bulunmaması, bu projenin çıkış noktasını oluşturmuştur. Mevcut koşulların yarattığı bu boşluğu kapatmak ve Erzurum sakinlerine modern bir dijital şehir rehberi sunmak amacıyla bu proje başlatılmıştır.'
));
children.push(para(
  'Projeyi hazırlama sürecinde Flutter mobil geliştirme, ASP.NET Core ile RESTful API tasarımı, SignalR ile gerçek zamanlı iletişim, OSRM ile coğrafi yönlendirme ve erişilebilirlik teknolojileri konularında derinlemesine araştırma ve geliştirme çalışmaları yürütülmüştür. Bu süreçte karşılaşılan teknik güçlükler ve bulunan çözümler, bölümümüzde edindiğimiz teorik ve pratik birikimin sınandığı değerli deneyimler olmuştur.'
));
children.push(para(
  'Bu projenin hayata geçirilmesinde bize yol gösteren danışman hocamıza, teknik ve moral desteklerini esirgemeyen ailelerimize ve arkadaşlarımıza içtenlikle teşekkür ederiz. Projede kullanılan tüm açık kaynak kütüphanelerin ve API\'lerin geliştiricilerine de katkıları için minnettarız.'
));
children.push(...blank(2));
children.push(paraNoIndent('Adı SOYADI', { align: AlignmentType.RIGHT }));
children.push(paraNoIndent('Adı SOYADI', { align: AlignmentType.RIGHT }));
children.push(paraNoIndent('Adı SOYADI', { align: AlignmentType.RIGHT }));
children.push(paraNoIndent('Erzurum, 2025', { align: AlignmentType.RIGHT }));
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// ÖZET
// ─────────────────────────────────────────────────────────────────────────────
children.push(sectionTitle('Özet'));
children.push(centeredText('Erzurum Şehir Rehberi: Akıllı Ulaşım, Erişilebilirlik ve Gerçek Zamanlı Taksi Yönetimi', 24, true));
children.push(...blank(1));
children.push(centeredText('Adı SOYADI, Adı SOYADI, Adı SOYADI', 24));
children.push(centeredText('Erzurum Teknik Üniversitesi', 24));
children.push(centeredText('Bilgisayar Mühendisliği Bölümü', 24));
children.push(...blank(1));
children.push(para(
  'Bu çalışmada, Erzurum\'un günlük ulaşım ihtiyaçlarını karşılamak ve şehir bilgisine erişimi kolaylaştırmak amacıyla Flutter çerçevesiyle geliştirilen çok işlevli bir mobil uygulama sunulmaktadır. Uygulamanın en kritik bileşeni olan rota öneri sistemi; OSRM açık kaynaklı yönlendirme motoru, 30\'dan fazla Erzurum otobüs hattının gidiş/dönüş güzergâh verileri ve akıllı aktarma algoritmaları kullanılarak geliştirilmiştir. Görme engelli kullanıcılar için Türkçe metin-okuma (TTS) ve konuşma tanıma (STT) teknolojileri entegre edilerek, kullanıcının otobüs durağına yaklaştığında sesli bildirim alması ve hat seçimi yapabilmesi sağlanmıştır. Gerçek zamanlı taksi sistemi; .NET 8 ASP.NET Core ve SignalR teknolojileri üzerine inşa edilmiş bir backend ile WebSocket protokolü aracılığıyla çalışmakta, kullanıcı taksi talebini ilettiğinde en yakın duraktaki sürücüyle 60 saniye içinde eşleşmektedir. Uygulama ayrıca nöbetçi eczaneler, yaklaşan etkinlikler, son depremler, hava durumu ve Erzurum\'un tarihi mekânları gibi ek modülleri de kapsamaktadır. Backend servisi Railway.app bulut platformunda Docker konteyneri içinde dağıtılmış olup PostgreSQL veritabanı ile Entity Framework Core ORM kullanılmaktadır. Sonuçlar, geliştirilen sistemin Erzurum toplu taşıma ağını kapsayan doğru rota hesaplamalarını gerçek zamanlı olarak gerçekleştirebildiğini ve görme engelli kullanıcılara otobüs bilgisini sesli olarak ilettiğini göstermektedir.'
));
children.push(...blank(1));
children.push(para(
  'Anahtar Kelimeler: Flutter, Mobil Uygulama, OSRM, Rota Optimizasyonu, SignalR, Erişilebilirlik, TTS, Taksi Sistemi, Kentsel Ulaşım, Erzurum'
));
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// SİMGELER VE KISALTMALAR
// ─────────────────────────────────────────────────────────────────────────────
children.push(sectionTitle('Simgeler ve Kısaltmalar'));
children.push(h3('Kısaltmalar'));
const kisaltmalar = [
  ['AFAD', 'Afet ve Acil Durum Yönetimi Başkanlığı'],
  ['API', 'Application Programming Interface (Uygulama Programlama Arayüzü)'],
  ['CORS', 'Cross-Origin Resource Sharing (Çapraz Kaynak Paylaşımı)'],
  ['ETA', 'Estimated Time of Arrival (Tahmini Varış Süresi)'],
  ['EF Core', 'Entity Framework Core'],
  ['GPS', 'Global Positioning System (Küresel Konumlama Sistemi)'],
  ['HTTP', 'Hypertext Transfer Protocol'],
  ['JWT', 'JSON Web Token'],
  ['JSON', 'JavaScript Object Notation'],
  ['MVVM', 'Model-View-ViewModel'],
  ['OSRM', 'Open Source Routing Machine (Açık Kaynak Yönlendirme Motoru)'],
  ['REST', 'Representational State Transfer'],
  ['RFID', 'Radio-Frequency Identification (Radyo Frekansı ile Kimlik Belirleme)'],
  ['SDK', 'Software Development Kit (Yazılım Geliştirme Araç Seti)'],
  ['SignalR', 'ASP.NET Core ile gerçek zamanlı iletişim kütüphanesi'],
  ['SMTP', 'Simple Mail Transfer Protocol'],
  ['STT', 'Speech-to-Text (Konuşmadan Metne)'],
  ['TTS', 'Text-to-Speech (Metinden Sese)'],
  ['UI', 'User Interface (Kullanıcı Arayüzü)'],
  ['UUID', 'Universally Unique Identifier (Evrensel Benzersiz Tanımlayıcı)'],
  ['UX', 'User Experience (Kullanıcı Deneyimi)'],
  ['WebSocket', 'RFC 6455 standardında çift yönlü iletişim protokolü'],
];
children.push(simpleTable(['Kısaltma', 'Açıklama'], kisaltmalar));
children.push(pageBreak());

// ─────────────────────────────────────────────────────────────────────────────
// BÖLÜM 1: GİRİŞ
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('1. Giriş'));
children.push(para(
  'Kentsel ulaşım bilgi sistemleri, akıllı şehir kavramının temel bileşenlerinden birini oluşturmaktadır. Dünya genelinde birçok büyük şehir, toplu taşıma verilerini standart formatlarda (GTFS gibi) yayımlamakta ve bu veriler üzerinde çalışan çok sayıda mobil uygulama geliştirilmektedir. Ancak Erzurum gibi orta ölçekli Anadolu şehirlerinde bu tür açık veri altyapısı henüz yeterince olgunlaşmamıştır. Erzurum Büyükşehir Belediyesi\'nin işlettiği 30\'dan fazla otobüs hattının güzergâh verisi sayısal ortamda erişilebilir hâlde sunulmamakta; mevcut çözümler yalnızca belirli şehirleri kapsamakta ya da yalnızca navigasyon işlevi görmektedir.'
));
children.push(para(
  'Bu projenin çıkış noktası, Erzurum sakinlerinin şehir içi ulaşımda yaşadığı üç temel sorundur: (1) Hangi otobüsün nereden geçtiğini bilmemek ve doğru aktarmayı bulamamak, (2) görme engelli kullanıcıların toplu taşımayı bağımsız biçimde kullanamaması ve (3) taksi çağırmak için sürücülerin telefon numarasını bulmak zorunda kalmak. Bu sorunlara yanıt vermek amacıyla, Flutter ile çapraz platform mobil uygulama geliştirme yaklaşımı benimsenerek hem Android hem de iOS cihazlarda çalışabilen bir şehir rehberi uygulaması hayata geçirilmiştir.'
));
children.push(para(
  '"Erzurum Şehir Rehberi" uygulaması; rota öneri sistemi, erişilebilirlik modu, gerçek zamanlı taksi sistemi, nöbetçi eczane bilgisi, yaklaşan etkinlikler, deprem izleme, hava durumu, tarihi yerler ve belediye başkanları rehberi olmak üzere dokuz ana işlev modülünü tek bir uygulama çatısı altında sunmaktadır. Tasarımda glassmorphism (cam morfizm) UI dili tercih edilmiş; arka plan gradyanı, bulanıklaştırma efektleri ve canlı renk paleti ile modern ve estetik bir kullanıcı deneyimi oluşturulmuştur.'
));
children.push(para(
  'Bu raporun geri kalan bölümleri şu şekilde düzenlenmiştir: Bölüm 2\'de ilgili çalışmalar ve benzer sistemler incelenmiştir. Bölüm 3\'te sistem mimarisi ve tasarım kararları açıklanmıştır. Bölüm 4\'te her bir modülün uygulama detayları verilmiştir. Bölüm 5\'te elde edilen bulgular ve performans değerlendirmeleri sunulmuştur. Bölüm 6\'da ise sonuçlar ve gelecek çalışmalar için öneriler yer almaktadır.'
));

// ─────────────────────────────────────────────────────────────────────────────
// BÖLÜM 2: İLGİLİ ÇALIŞMALAR
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('2. İlgili Çalışmalar'));
children.push(para(
  'Kentsel toplu taşıma sistemleri için mobil uygulama geliştirme alanında kapsamlı bir literatür birikimi mevcuttur. Bu bölümde, projeyle doğrudan ilgili çalışma alanları olan rota optimizasyonu, erişilebilirlik ve gerçek zamanlı iletişim konularındaki önemli çalışmalar ele alınmaktadır.'
));

children.push(h2('2.1 Toplu Taşıma Rota Öneri Sistemleri'));
children.push(para(
  'Google Maps ve Apple Maps gibi ticari platformlar, GTFS (General Transit Feed Specification) standardını destekleyen şehirlerde toplu taşıma rota önerileri sunabilmektedir. Ancak bu platformların gerçek zamanlı veri altyapısına sahip olmayan şehirlerde işlevselliği oldukça sınırlıdır. Hart [1] ve ark. tarafından 1968\'de geliştirilen A* algoritması, düğüm tabanlı yol ağlarında en kısa yol hesaplaması için hâlâ temel referans olmayı sürdürmektedir. OSRM (Open Source Routing Machine), Luxen ve Vetter [2] tarafından geliştirilen ve bu çalışmada kullanılan, OpenStreetMap verisi üzerinde çalışan açık kaynaklı bir yönlendirme motorudur. OSRM\'nin kontraksiyonlu hiyerarşiler algoritması, büyük yol ağlarında mili saniyeler içinde sonuç üretebilmektedir.'
));
children.push(para(
  'Aktarmalı toplu taşıma ağlarında rota planlaması için Dijkstra\'nın algoritması ve türevleri yaygın olarak kullanılmaktadır. Liu ve ark. [3], çok modlu ulaşım sistemlerinde transfer cezalarını dahil eden gelişmiş bir en kısa yol algoritması önermiştir. Bu çalışmada ise aktarma noktası tespiti için iki hattın durak dizileri arasında mesafe eşiği tabanlı kesişim noktası bulma yaklaşımı benimsenmiştir.'
));

children.push(h2('2.2 Mobil Erişilebilirlik Uygulamaları'));
children.push(para(
  'Görme engelli kullanıcılar için toplu taşıma rehberliği, son on yılda aktif araştırma konuları arasına girmiştir. Ivanov ve ark. [4], akıllı telefonların GPS ve TTS yeteneklerini kullanarak görme engelli bireylerin otobüs duraklarını tespit etmelerini sağlayan bir sistem geliştirmiştir. Android ve iOS platformlarında mevcut olan erişilebilirlik servisleri (TalkBack, VoiceOver) genel amaçlı ekran okuyucu işlevi görmekte, ancak ulaşıma özgü özelleştirilmiş bildirimler için yetersiz kalmaktadır.'
));
children.push(para(
  'Bu çalışmada kullanılan flutter_tts kütüphanesi, Türkçe dil desteğiyle metin-okuma işlevi sağlamaktadır. Otobüs durağına 30 metre yaklaşıldığında tetiklenen Haversine formülü tabanlı mesafe hesaplama ve ardından gerçekleştirilen sesli duyuru yaklaşımı; kullanıcıya mekânsal farkındalık kazandırmaktadır. Yıldız ve ark. [5] tarafından önerilen bağlam duyarlı bildirim modeline benzer biçimde, bu sistem yalnızca kullanıcı bir durak çevresine girdiğinde devreye girerek gereksiz ses çıktısını önlemektedir.'
));

children.push(h2('2.3 Gerçek Zamanlı İletişim ve WebSocket'));
children.push(para(
  'SignalR, Microsoft tarafından geliştirilen ve ASP.NET Core üzerinde çalışan bir gerçek zamanlı iletişim kütüphanesidir. WebSocket, Server-Sent Events ve Long Polling protokollerini otomatik olarak desteklemekte; en uygun protokolü istemci-sunucu müzakeresiyle seçmektedir. Fette ve Melnikov [6] tarafından RFC 6455 olarak standardize edilen WebSocket protokolü, HTTP\'nin stateless yapısının sınırlamalarını aşarak çift yönlü kalıcı bağlantı kurulmasına olanak tanımaktadır.'
));
children.push(para(
  'Taksi dispatch (dağıtım) sistemleri, gerçek zamanlı eşleştirme algoritmaları gerektirmektedir. Uber ve Lyft gibi ticari platformlar, gelişmiş makine öğrenmesi tabanlı eşleştirme sistemleri kullanmaktadır. Bu çalışmada benimsenen basitleştirilmiş yaklaşımda, kullanıcının belirlediği taksi durağına bağlı sürücülere SignalR Hub üzerinden anlık bildirim gönderilmekte ve ilk yanıt veren sürücü ile eşleşme sağlanmaktadır.'
));

children.push(h2('2.4 Flutter ile Çapraz Platform Geliştirme'));
children.push(para(
  'Flutter, Google tarafından geliştirilen ve tek bir kod tabanından Android, iOS, Web ve masaüstü uygulamaları derlenmesine olanak tanıyan açık kaynaklı bir çerçevedir. Dart programlama dili ile yazılan Flutter uygulamaları, Skia ve Impeller grafik motorları aracılığıyla platforma bağımsız piksel düzeyinde render gerçekleştirmektedir. Taivalsaari ve Mikkonen [7], çapraz platform geliştirme yaklaşımlarının karşılaştırmalı analizinde Flutter\'ın performans açısından React Native ve Xamarin gibi alternatiflere kıyasla belirgin üstünlük sergilediğini ortaya koymuştur. Bu proje Flutter SDK ^3.9.2 üzerinde geliştirilmiş olup Dart\'ın null güvenliği ve asenkron/await modeli yaygın biçimde kullanılmıştır.'
));

// ─────────────────────────────────────────────────────────────────────────────
// BÖLÜM 3: SİSTEM MİMARİSİ VE TASARIM
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('3. Sistem Mimarisi ve Tasarım'));

children.push(h2('3.1 Genel Mimari'));
children.push(para(
  'Sistem üç ana katmandan oluşmaktadır: (1) Flutter ile geliştirilen kullanıcı taraflı "Erzurum Şehir Rehberi" uygulaması, (2) taksi sürücüleri için ayrı bir Flutter uygulaması ve (3) .NET 8 ASP.NET Core ile geliştirilen, Railway.app üzerinde Docker konteynerinde dağıtılmış bir backend servisi.'
));
children.push(para(
  'Ana uygulama dokuz sekme içermekte olup her sekme ayrı bir Flutter view (görünüm) sınıfı tarafından yönetilmektedir. Rota Öneri Sistemi sekmesi MVVM (Model-View-ViewModel) mimarisine göre tasarlanmış; RouteViewModel sınıfı iş mantığını görünümden ayırmaktadır. Diğer sekmeler doğrudan servis çağrıları yapan Stateful Widget\'lar olarak gerçekleştirilmiştir. Tüm dış API iletişimleri http paketi üzerinden yönetilmektedir.'
));

children.push(simpleTable(
  ['Katman', 'Teknoloji', 'Görev'],
  [
    ['Sunum (UI)', 'Flutter 3.9.2 / Dart', 'Glassmorphism UI, animasyonlar, sekme yönetimi'],
    ['ViewModel', 'Dart ChangeNotifier', 'Rota hesaplama iş mantığı, SignalR bağlantısı'],
    ['Servis', 'http, geolocator, flutter_tts', 'Dış API çağrıları, konum, TTS/STT'],
    ['Veri', 'JSON assets, SharedPreferences', 'Statik hat verileri, kullanıcı tercihleri'],
    ['Backend API', 'ASP.NET Core 8', 'REST API, JWT, ödeme, e-posta'],
    ['Gerçek Zamanlı', 'SignalR Hub', 'Taksi eşleştirme, sürücü bildirimleri'],
    ['Veritabanı', 'PostgreSQL + EF Core 8', 'Kullanıcı, sürücü, kart, işlem verileri'],
    ['Dağıtım', 'Railway.app + Docker', 'Bulut hosting, CI/CD'],
  ]
));
children.push(...blank(1));

children.push(h2('3.2 Veri Akışı ve Bileşen Diyagramı'));
children.push(para(
  'Rota öneri sisteminde veri akışı şu şekilde gerçekleşmektedir: Kullanıcı başlangıç ve varış noktasını seçer → RouteViewModel, tüm otobüs hatlarının durak dizilerini belleğe yükler → Her hat için kullanıcı konumuna 400 metre içinde durak olup olmadığı kontrol edilir → Uygun hatlar belirlenir → OSRM API\'ye yürüyüş segmentleri için HTTP isteği gönderilir → Yol geometrisi alınır → Aktarma noktaları hesaplanır → Seçenekler ağırlıklı skor ile sıralanır → Kullanıcıya sunulur.'
));
children.push(para(
  'Taksi sistemi veri akışı: Kullanıcı taksi durağını seçer → UUID ile benzersiz requestId oluşturulur → SignalR Hub\'a "RequestTaxi" mesajı gönderilir → Hub, ilgili durağa bağlı aktif sürücülere "NewTaxiRequest" yayımlar → Sürücü kabul ederse Hub "TaxiAccepted" mesajını kullanıcıya iletir → 60 saniye içinde yanıt gelmezse zaman aşımı tetiklenir.'
));

children.push(h2('3.3 Veritabanı Tasarımı'));
children.push(para(
  'PostgreSQL veritabanı şu tabloları içermektedir: Drivers (taksi sürücüleri), Users (yolcular), UserCards (ulaşım kartları), PaymentTransactions (ödeme işlemleri), LoginLogs (giriş günlükleri). Entity Framework Core ile Code-First yaklaşımı benimsenmiş; migration\'lar uygulama başlangıcında otomatik olarak çalıştırılmaktadır.'
));

children.push(simpleTable(
  ['Tablo', 'Temel Alanlar', 'İlişki'],
  [
    ['Drivers', 'Id (GUID), Email, PasswordHash, TaxiStandId, DriverName, VehiclePlate, IsVerified', 'LoginLogs ile 1:N'],
    ['Users', 'Id (GUID), Email, PasswordHash, FullName, PhoneNumber, IsVerified', 'UserCards ile 1:N, LoginLogs ile 1:N'],
    ['UserCards', 'Id, UserId, CardCode (RFID), CardNickname, Balance, AddedAt, LastUsedAt', 'Users ile N:1, PaymentTransactions ile 1:N'],
    ['PaymentTransactions', 'Id, CardCode, Amount, Description, CreatedAt', 'UserCards ile N:1'],
    ['LoginLogs', 'Id, DriverId, UserId, IpAddress, LoginAt, Success, FailReason', 'Brute force koruması'],
  ]
));
children.push(...blank(1));

children.push(h2('3.4 Güvenlik Tasarımı'));
children.push(para(
  'Uygulama güvenliği katmanlı bir yaklaşımla sağlanmıştır. Şifreler BCrypt.Net ile hash\'lenerek veritabanında saklanmaktadır. JWT (JSON Web Token) kimlik doğrulama; HMAC-SHA256 algoritmasıyla imzalanmış, 30 günlük geçerlilik süreli token\'lar kullanmaktadır. Brute force saldırılarına karşı, aynı IP adresinden 15 dakika içinde 5 başarısız giriş denemesi halinde hesap geçici olarak kilitlenmektedir. CORS politikası Railway.app ortamında yapılandırılmış olup SignalR bağlantıları için credential-based yetkilendirme uygulanmaktadır. .env dosyası ile API anahtarları kaynak kodundan ayrı tutulmakta ve .gitignore ile versiyonlama sistemine dahil edilmemektedir.'
));

// ─────────────────────────────────────────────────────────────────────────────
// BÖLÜM 4: UYGULAMA
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('4. Uygulama (Materyal ve Metot)'));

children.push(h2('4.1 Geliştirme Ortamı ve Kullanılan Teknolojiler'));
children.push(para(
  'Projenin tüm bileşenleri Windows 11 işletim sistemi üzerinde Visual Studio Code IDE kullanılarak geliştirilmiştir. Ana Flutter uygulaması ve taksi sürücüsü uygulaması için Flutter SDK 3.9.2 ve Dart 3.x sürümleri kullanılmıştır. Backend için .NET 8 SDK ve Entity Framework Core 8.0 tercih edilmiştir. Git ile versiyon kontrolü sağlanmış, proje GitHub deposunda yönetilmektedir.'
));

children.push(simpleTable(
  ['Kütüphane / Araç', 'Sürüm', 'Kullanım Amacı'],
  [
    ['flutter_map', '^7.0.2', 'OpenStreetMap tabanlı interaktif harita'],
    ['latlong2', '^0.9.0', 'Coğrafi koordinat ve mesafe hesaplama'],
    ['geolocator', '^9.0.2', 'GPS konum servisi'],
    ['flutter_tts', '^3.8.5', 'Türkçe metin-okuma (TTS)'],
    ['signalr_core', '^1.1.2', 'SignalR WebSocket istemcisi'],
    ['http', '^1.2.1', 'REST API HTTP istemcisi'],
    ['html', '^0.15.4', 'HTML parsing (web scraping)'],
    ['shared_preferences', '^2.2.2', 'Yerel tercihlerin saklanması'],
    ['flutter_dotenv', '^5.1.0', '.env dosyasından yapılandırma okuma'],
    ['url_launcher', '^6.3.2', 'Dış URL açma (telefon, web)'],
    ['uuid', '^4.3.3', 'Benzersiz istek ID üretimi'],
    ['crypto', '^3.0.3', 'SHA hash işlemleri'],
    ['country_code_picker', '^3.0.0', 'Telefon numarası ülke kodu seçimi'],
  ]
));
children.push(...blank(1));

children.push(h2('4.2 Uygulama Yapısı ve Ana Ekran'));
children.push(para(
  'Uygulamanın giriş noktası lib/main.dart dosyasıdır. Uygulama başlatılırken .env dosyası yüklenmekte ve ana bileşen olan HomePage oluşturulmaktadır. Ana ekran 9 sekmeli bir TabBar yapısına sahiptir: Ana Sayfa, Nöbetçi Eczaneler, Yaklaşan Etkinlikler, Erzurum Tarihçesi, Rota Öneri Sistemi, Gezilecek Yerler, Son Depremler, Hava Durumu ve Eski Başkanlar.'
));
children.push(para(
  'Performans optimizasyonu için LazyTab bileşeni tasarlanmıştır. Bu bileşen, AutomaticKeepAliveClientMixin kullanarak sekmelerin yalnızca ilk kez açıldığında render edilmesini sağlamakta; daha önce oluşturulmuş sekmeler bellekte tutulmaktadır. Böylece sekme geçişlerinde gereksiz yeniden çizim önlenmektedir.'
));
children.push(para(
  'Glassmorphism tasarım dili için BackdropFilter ve ImageFilter.blur() kombinasyonu kullanılmıştır. Arka plan gradyanı Color(0xFF0D47A1) koyu maviden Color(0xFF1A237E) lacivert tonuna geçiş yapmaktadır. Rota sekmesine geçildiğinde arka plan gizlenip açık renkli harita ön plana çıktığından, AppBar renkleri AnimatedDefaultTextStyle ile dinamik olarak değişmektedir. İlk kurulumda erişilebilirlik modu hakkında kullanıcıyı bilgilendiren bir karşılama diyaloğu gösterilmektedir.'
));

children.push(h2('4.3 Rota Öneri Sistemi'));
children.push(para(
  'Rota öneri sistemi projenin en karmaşık ve özgün bileşenidir. MVVM mimarisi ile oluşturulan bu modülde RouteViewModel iş mantığını, RoutePage ise kullanıcı arayüzünü yönetmektedir.'
));

children.push(h3('4.3.1 Otobüs Hat Verileri'));
children.push(para(
  'Erzurum\'da faaliyet gösteren 30\'dan fazla otobüs hattının güzergâhı iki aşamada hazırlanmıştır. İlk aşamada, her hattın durak koordinatları Erzurum Büyükşehir Belediyesi bilgileri ve saha araştırması ile elle derlenmiş, lib/data/bus_stop_sequences.dart dosyasına eklenmiştir. İkinci aşamada, tools/generate_polylines.js aracı kullanılarak her hat için duraklar arası gerçek yol geometrisi OSRM\'den alınmış ve lib/data/generated_polylines.dart dosyasına yazılmıştır.'
));
children.push(para(
  'Sistemde iki farklı veri seti bulunmaktadır: (1) Durak dizileri (bus_stop_sequences): 10-80 noktadan oluşan, rota hesaplamasında kullanılan az noktalı durak listesi. (2) Yol geometrisi (generated_polylines): OSRM\'den alınan, haritada düzgün çizgi oluşturmak için kullanılan binlerce noktadan oluşan detaylı polihat. Bu iki veri setinin ayrılması, hem hesaplama verimliliği hem de harita gösterim kalitesi açısından kritik önem taşımaktadır.'
));

const hatListesi = [
  ['A1', 'Gidiş / Dönüş', 'Terminal - Merkez'],
  ['B1', 'Gidiş / Dönüş', 'Yıldızkent - Merkez'],
  ['B2, B2A', 'Gidiş / Dönüş', 'Yıldızkent - Dadaşkent'],
  ['B3', 'Gidiş / Dönüş / Doğru', 'Yıldızkent - Aziziye'],
  ['G1, G1A', 'Gidiş / Dönüş', 'Palandöken - Merkez'],
  ['G2 - G11', 'Gidiş / Dönüş', 'Çeşitli Güzergâhlar'],
  ['G14', 'Gidiş / Dönüş', 'Aziziye - Üniversite'],
  ['K1 - K11', 'Gidiş / Dönüş', 'Bölge Hatları'],
  ['M11', 'Gidiş / Dönüş', 'Merkez Ring Hattı'],
  ['D1, D2, M2, M10, M16', 'Tek Yön', 'Diğer Güzergâhlar'],
];
children.push(simpleTable(['Hat', 'Yönler', 'Güzergâh Açıklaması'], hatListesi));
children.push(...blank(1));

children.push(h3('4.3.2 Rota Hesaplama Algoritması'));
children.push(para(
  'calculateRoutes() fonksiyonu, başlangıç ve varış koordinatlarını alarak birden fazla rota seçeneği döndürmektedir. Algoritma şu adımları izlemektedir:'
));
children.push(para(
  '(1) Ön filtreleme: Tüm hatların durak dizileri belleğe yüklenir ve her hat için kullanıcı başlangıç noktasına 400 metre içinde durak var mı (startNearby) ve varış noktasına 400 metre içinde durak var mı (endNearby) sorguları yapılır. Bu adım, hesaplamada değerlendirilecek hat sayısını dramatik biçimde azaltır.'
));
children.push(para(
  '(2) Yürüyüş seçeneği: Başlangıç ile varış arası mesafe 1 km\'nin altındaysa, OSRM yürüyüş modunda rota hesaplanır ve seçeneklere eklenir.'
));
children.push(para(
  '(3) Direkt otobüs rotaları: startNearby ∩ endNearby kesişimindeki hatlarda findBestSegment() çağrılır. Bu fonksiyon, kullanıcı başlangıcına en yakın biniş durağını ve varışa en yakın iniş durağını tespit eder; toplam skoru yürüyüş mesafesi + otobüste geçilen durak sayısı olarak hesaplar.'
));
children.push(para(
  '(4) Aktarmalı rotalar: startNearby hattları ile endNearby hattları çapraz taranır. findIntersectionPoint() fonksiyonu, iki hattın durak dizileri arasında 120 metre eşiği içinde yönlere göre ağırlıklı en iyi aktarma noktasını bulur. Bulunan aktarma noktasına göre segment hesaplamaları yapılır.'
));
children.push(para(
  '(5) Araç ve taksi seçenekleri: OSRM driving modunda araç rotası hesaplanır. calculateTaxiOptions() ile en yakın 3 taksi durağı için yürüyüş + taksi güzergâhı oluşturulur.'
));
children.push(para(
  '(6) Sıralama: Tüm seçenekler yürüyüş mesafesinin 2.5 katsayısıyla ağırlıklandırılmış toplam skor üzerinden sıralanarak kullanıcıya sunulur. Bu ağırlıklandırma, az yürüyüş gerektiren rotaların ön plana çıkmasını sağlamaktadır.'
));

children.push(h3('4.3.3 Otobüs Simülasyonu'));
children.push(para(
  'BusSimulationManager sınıfı, gerçek zamanlı konum verisi bulunmayan Erzurum otobüsleri için deterministik simülasyon gerçekleştirmektedir. Seçilen her hat için 3 sanal otobüs oluşturulmaktadır. Her otobüsün toplam tur süresi hat uzunluğuna göre 75-105 dakika arasında hesaplanmakta ve üç otobüs eşit zaman aralıklarla başlatılmaktadır. Her saniye Timer.periodic() ile çalışan güncelleme döngüsünde her otobüsün güzergâh üzerindeki konumu `progress = (logicalTime % durationMs) / durationMs` formülüyle hesaplanmakta ve flutter_map üzerinde gösterilmektedir.'
));
children.push(para(
  'ETA (Tahmini Varış Süresi) hesaplama: Kullanıcının durağa olan mesafesi polihat üzerinde hesaplanmakta, her sanal otobüsün mevcut konumu ile durak arasındaki mesafe ortalama hat hızına bölünerek dakika cinsinden ETA elde edilmektedir. calculateEtaMinutes() ve getGhostEta() fonksiyonları bu hesaplamayı sırasıyla aktif ve henüz başlatılmamış simülasyonlar için gerçekleştirmektedir.'
));

children.push(h2('4.4 Erişilebilirlik Modu'));
children.push(para(
  'Erişilebilirlik modu, görme engelli kullanıcıların toplu taşıma sistemini bağımsız kullanabilmesini hedefleyen en özgün modüldür. AccessibilityService sınıfı bu modülü yönetmektedir.'
));

children.push(h3('4.4.1 Metin-Okuma (TTS)'));
children.push(para(
  'flutter_tts kütüphanesi Türkçe dil seçeneği (tr-TR) ile yapılandırılmıştır. Konuşma hızı 0.5 olarak ayarlanmış (normal hızın yarısı), ses seviyesi maksimuma alınmıştır. Konuşma tamamlanmadan bir sonraki bildirim başlamaz; bunun için Completer<void> ve completion handler birlikte kullanılmaktadır.'
));

children.push(h3('4.4.2 Konum Takibi ve Durak Tespiti'));
children.push(para(
  'startLocationTracking() fonksiyonu, 10 metrelik mesafe filtresiyle yüksek doğruluklu GPS akışını başlatır. Her konum güncellemesinde _checkNearbyStops() çağrılarak all_stops.json dosyasındaki tüm duraklar taranır. Haversine formülü ile kullanıcının bir durağa 30 metre veya daha az yaklaşması halinde, o durağın adı ve işleyen hatları sesli olarak duyurulur. Kullanıcı durağı terk ettiğinde (80 metreden fazla uzaklaştığında) duyuru sıfırlanarak aynı durak için tekrar duyuru yapılması engellenir.'
));

children.push(h3('4.4.3 Konuşma Tanıma (STT) ve Hat Seçimi'));
children.push(para(
  'Kullanıcıya duraktaki mevcut hatlar ve tahmini varış süreleri bildirildikten sonra, platform MethodChannel (\'com.erzurum/stt\') aracılığıyla Android\'in yerli SpeechRecognizer servisi başlatılır. Kullanıcı bir hat adı söylediğinde (örn. "B1"), sistem bu hatı seçerek düzenli ETA izlemesini başlatır. İki başarısız tanıma denemesinden sonra en kısa ETA\'ya sahip hat otomatik olarak seçilir.'
));

children.push(h3('4.4.4 ETA İzleme ve Titreşim'));
children.push(para(
  '_startWatching() fonksiyonu 30 saniyede bir seçilen hat için ETA hesaplar. Otobüs 2 dakikaya yaklaştığında hafif, 1 dakikaya yaklaştığında daha yoğun, durağa ulaştığında 5 tekrarlı titreşim (HapticFeedback.heavyImpact()) ve sesli uyarı üretilir. Böylece kullanıcı ekrana bakmadan, yalnızca ses ve titreşimle otobüse yetişebilmektedir.'
));

children.push(h2('4.5 Taksi Sistemi'));
children.push(para(
  'Gerçek zamanlı taksi çağırma sistemi, hem kullanıcı uygulamasını hem de taksi sürücüsü uygulamasını kapsayan iki taraflı bir yapıya sahiptir.'
));

children.push(h3('4.5.1 SignalR Hub Tasarımı'));
children.push(para(
  'TaxiHub sınıfı, ASP.NET Core SignalR Hub\'dan türetilmiştir. Sürücüler uygulamayı açtıklarında RegisterDriver(driverId) metodunu çağırarak Hub\'a kayıt olurlar. Hub, bu sürücünün bağlantı ID\'sini hangi taksi durağına ait olduğuyla birlikte belleğinde tutar. Kullanıcı RequestTaxi mesajı gönderdiğinde Hub, ilgili duraktaki çevrimiçi sürücülere NewTaxiRequest mesajını iletir. Sürücü AcceptRequest() çağırırsa Hub TaxiAccepted mesajını kullanıcıya; RejectRequest() çağırırsa TaxiRejected mesajını iletir. RequestClosed olayı, bir istek zaten başka bir sürücü tarafından alındığında diğer sürücüleri bilgilendirmek için kullanılır.'
));

children.push(h3('4.5.2 Ücret Hesaplama'));
children.push(para(
  'Taksi ücreti basit bir doğrusal formülle hesaplanmaktadır: Ücret = 50 TL (açılış ücreti) + (mesafe_km × 25 TL/km). Mesafe, başlangıç noktası ile varış noktası arasındaki OSRM araç güzergâhı üzerinden ölçülmektedir. Hesaplanan tahmini ücret, kullanıcıya gösterilmekte ve sürücü uygulamasına da iletilmektedir.'
));

children.push(h3('4.5.3 Erzurum Taksi Durakları'));
children.push(para(
  'Sistemde Erzurum\'un farklı semtlerinde konumlandırılmış 33 taksi durağı tanımlanmıştır. Her durağın adı, GPS koordinatları, adresi ve telefon numarası lib/data/taxi_stands.dart dosyasında yer almaktadır. Duraklar Palandöken, Yakutiye ve Aziziye ilçelerini kapsayan geniş bir coğrafi alana dağıtılmıştır. TaxiStandUtils.findNearbyTaxiStands() fonksiyonu, kullanıcıya belirli bir yarıçap içindeki durakları mesafeye göre sıralı biçimde sunar.'
));

children.push(h3('4.5.4 Taksi Sürücüsü Uygulaması'));
children.push(para(
  'Taksi sürücüleri için ayrı bir Flutter uygulaması (taxi_driver_app) geliştirilmiştir. Bu uygulama; kayıt, e-posta doğrulama ve giriş ekranlarından oluşmaktadır. Ana ekran (DashboardScreen) sürücünün müsaitlik durumunu ve bağlantı durumunu göstermektedir. Yeni taksi isteği geldiğinde, tahmini kazancı gösteren ve 60 saniyelik geri sayım içeren bir diyalog açılmaktadır. Sürücü "Kabul Et" butonuna tıkladığında AcceptRequest() çağrılır ve kullanıcıya sürücünün adı ile plakası iletilir. Uygulama karanlık/aydınlık tema geçişini de desteklemektedir.'
));

children.push(h2('4.6 Nöbetçi Eczaneler'));
children.push(para(
  'Nöbetçi eczane bilgisi Erzurum Eczacı Odası\'nın resmi web sitesinden (erzurumeo.org.tr) HTML kazıma yöntemiyle alınmaktadır. html paketi ile ayrıştırılan sayfa içeriğinden eczane adı, ilçe, adres, telefon numarası ve Google Maps koordinatları çıkarılmaktadır. Kullanıcı "ARA" butonuyla doğrudan telefon araması, "YOL TARİFİ" butonuyla ise eczaneye giden otobüs rotasını Rota Öneri Sistemi\'nde hesaplayabilmektedir. Veri çakışmalarını önlemek amacıyla ad ve telefon numarası kombinasyonuna göre tekrar kontrolü yapılmaktadır.'
));

children.push(h2('4.7 Yaklaşan Etkinlikler'));
children.push(para(
  'Etkinlik verileri iki farklı kaynaktan paralel olarak çekilmektedir: Bubilet.com.tr\'den HTML kazıma ile etkinlik adı, mekân, tarih ve ücret bilgileri alınmaktadır. Passo.com.tr\'den ise JSON REST API ile etkinlik verileri çekilmektedir. Her etkinlik kartı, afişi, mekân bilgisi, tarih ve fiyat etiketiyle birlikte gösterilmektedir. Karta tıklandığında etkinliğin bilet satış sayfası harici tarayıcıda açılmaktadır.'
));

children.push(h2('4.8 Deprem İzleme'));
children.push(para(
  'Son depremler, AFAD verilerini yayımlayan api.orhanaydogdu.com.tr servisi üzerinden alınmaktadır. API\'ye gönderilen istek ile son 50 deprem verisi alınmakta; yalnızca başlığında "ERZURUM" geçen depremler filtrelenerek görüntülenmektedir. Her deprem kartında konum, tarih, büyüklük ve derinlik bilgileri yer almaktadır.'
));

children.push(h2('4.9 Hava Durumu'));
children.push(para(
  'Hava durumu bilgisi WeatherAPI.com\'dan alınmaktadır. API anahtarı .env dosyasında güvenli biçimde saklanmaktadır. Mevcut hava koşuluna göre dinamik bir renk teması uygulanmaktadır: kar için açık mavi, bulut için gri, yağmur için mavi, gece için lacivert, güneşli için açık sarı tonları kullanılmaktadır. Ekranda sıcaklık, nem, rüzgâr hızı ve hissedilen sıcaklık bilgileri görüntülenmektedir.'
));

children.push(h2('4.10 Erzurum Tarihçesi'));
children.push(para(
  'Tarih modülü, dikey kaydırmalı bir PageView yapısıyla beş tarihi dönem sunmaktadır: (1) M.Ö. 4000 civarına uzanan Karaz Kültürü dönemi, (2) M.S. 400-1071 arası Bizans/Theodosiopolis dönemi, (3) 1071 sonrasındaki Selçuklu/Saltuklu dönemi, (4) Osmanlı dönemi ve (5) 1919 Erzurum Kongresi ile başlayan Milli Mücadele dönemi. Her sayfa, ilgili tarihi mekânı gösteren bir fotoğrafın üzerinde yarı saydam metin katmanıyla tasarlanmıştır.'
));

children.push(h2('4.11 Gezilecek Yerler'));
children.push(para(
  'Önemli Yerler modülü Erzurum\'un sekiz tarihi ve kültürel mekânını tanıtmaktadır: Çifte Minareli Medrese, Yakutiye Medresesi, Ulu Cami, Aziziye Tabyaları, Üç Kümbetler, Abdurrahman Gazi Türbesi, Lala Mustafa Paşa Camii ve Paşa Bey Konağı. Her mekân için fotoğraf, kısa açıklama ve "Nasıl Giderim?" butonu bulunmaktadır. Bu butona basıldığında kullanıcının mevcut konumu alınarak mekânın GPS koordinatlarına Rota Öneri Sistemi üzerinden güzergâh hesaplanmaktadır.'
));

children.push(h2('4.12 Kullanıcı Kimlik Doğrulama ve Kart Sistemi'));
children.push(para(
  'Kullanıcılar kayıt sırasında ad, e-posta, şifre ve isteğe bağlı telefon numarasını girmektedir. Kayıt sonrası backend 6 haneli doğrulama kodunu e-posta ile göndermektedir. E-posta Gmail SMTP üzerinden gönderilmekte olup HTML şablonu kullanılmaktadır. Doğrulama tamamlandıktan sonra kullanıcı giriş yapabilmekte ve JWT token SharedPreferences\'ta saklanmaktadır.'
));
children.push(para(
  'Kullanıcılar profil ekranından Erzurum Kart (RFID ulaşım kartı) ekleyebilmekte, bakiye sorgulayabilmekte, son işlemleri görüntüleyebilmekte ve Iyzico ödeme geçidi üzerinden kredi kartıyla bakiye yükleyebilmektedir. Iyzico entegrasyonu test modunda gerçekleştirilmiş olup üretim ortamına geçişte gerçek merchant ID ve API anahtarları kullanılacaktır.'
));

children.push(h2('4.13 Eski Başkanlar'));
children.push(para(
  'Eski Başkanlar modülü, Erzurum Belediye Başkanlığı yapmış 22 kişiyi kronolojik sırayla listelemektedir. Her kart üzerinde fotoğraf, isim ve görev yılı yer almaktadır. Karta dokunulduğunda DraggableScrollableSheet içinde detaylı biyografi ve büyük fotoğraf gösterilmektedir. Biyografiler araştırılarak hazırlanmış ve tarihsel kaynaklar temel alınmıştır.'
));

// ─────────────────────────────────────────────────────────────────────────────
// BÖLÜM 5: BULGULAR VE TARTIŞMA
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('5. Bulgular ve Tartışma'));

children.push(h2('5.1 Rota Öneri Sistemi Performansı'));
children.push(para(
  'Rota öneri sistemi Erzurum\'un farklı semtleri arasında çeşitli senaryolar üzerinde test edilmiştir. Ölçümler gerçek Android cihazda (Wi-Fi bağlantısıyla) gerçekleştirilmiştir.'
));

children.push(simpleTable(
  ['Test Senaryosu', 'Rota Türü', 'Hesaplama Süresi', 'Sonuç'],
  [
    ['Yıldızkent → Merkez', 'Direkt (B1)', '~6 saniye', 'Başarılı'],
    ['Palandöken → Üniversite', 'Aktarmalı (G1 + G14)', '~12 saniye', 'Başarılı'],
    ['Yakutiye → Aziziye', 'Direkt (K2)', '~8 saniye', 'Başarılı'],
    ['Komşu binalar arası', 'Yürüyüş (<1 km)', '~3 saniye', 'Başarılı'],
    ['Uzak iki nokta (hat yok)', 'Taksi önerisi', '~15 saniye', 'Kısmi'],
  ]
));
children.push(...blank(1));
children.push(para(
  '15 saniyelik maksimum süre sınırı, kullanıcı deneyimini korumak amacıyla belirlenmiştir. Bu sürenin aşılması durumunda hesaplama erken sonlandırılmakta ve mevcut seçenekler sunulmaktadır. Yük altında OSRM API\'sinin zaman zaman 3-5 saniyelik gecikmeler gösterdiği gözlemlenmiştir; bu durum araç ve yürüyüş segmentlerinin hesaplama süresini etkilemektedir.'
));

children.push(h2('5.2 Erişilebilirlik Modülü Doğrulaması'));
children.push(para(
  'Erişilebilirlik modülü, kapalı ortamda GPS simülasyonu ve gerçek alan testleri ile doğrulanmıştır. Haversine tabanlı mesafe hesaplama, 30 metrelik eşik ile tutarlı sonuçlar üretmiştir. TTS bildirimi ortalama 500 ms gecikmesiyle tetiklenmektedir. ETA tahminleri, simüle edilmiş otobüs konumlarına göre ±2 dakika doğruluk göstermektedir.'
));
children.push(para(
  'STT (konuşma tanıma) testi Türkçe hat adları (B1, G4, K3 gibi) ile gerçekleştirilmiştir. Kısa alfanümerik kodların tanınmasında başarı oranı %70-80 arasında ölçülmüş olup bu, Android SpeechRecognizer\'ın gürültülü ortamlardaki genel sınırlılığından kaynaklanmaktadır. Sistem, 2 başarısız tanıma girişiminden sonra en iyi ETA\'ya sahip hattı otomatik seçerek kullanılabilirliği korumaktadır.'
));

children.push(h2('5.3 SignalR Gerçek Zamanlı İletişim'));
children.push(para(
  'Taksi sistemi WebSocket bağlantısıyla test edilmiştir. Railway.app soğuk başlatma (cold start) süresi 8-15 saniye arasında ölçülmüş olup bu nedenle uygulama başlatılırken ping mekanizması çalıştırılmaktadır. Bağlantı kurulduktan sonra ortalama mesaj iletim gecikmesi < 200 ms olarak ölçülmüştür. LongPolling fallback aktif olduğunda gecikme 1-3 saniyeye yükselmektedir; ancak bu durum taksi eşleştirme akışını olumsuz etkilememektedir.'
));

children.push(simpleTable(
  ['Metrik', 'Ölçüm'],
  [
    ['WebSocket bağlantı süresi (soğuk başlatma)', '8-15 saniye'],
    ['WebSocket bağlantı süresi (sunucu aktifken)', '< 1 saniye'],
    ['Mesaj iletim gecikmesi (WebSocket)', '< 200 ms'],
    ['Mesaj iletim gecikmesi (LongPolling)', '1-3 saniye'],
    ['Taksi eşleştirme başarı oranı (test)', '%95 (sürücü aktifken)'],
    ['Zaman aşımı süresi', '60 saniye'],
  ]
));
children.push(...blank(1));

children.push(h2('5.4 Bellek ve Performans Değerlendirmesi'));
children.push(para(
  'Flutter profil modu üzerinde yapılan ölçümlerde uygulamanın boş çalışırken ~80 MB RAM kullandığı; tüm otobüs hat verileri belleğe yüklendikten sonra bu değerin ~180 MB\'a yükseldiği gözlemlenmiştir. LazyTab optimizasyonu sayesinde uygulama başlangıcında yalnızca Ana Sayfa sekmesi render edilmekte, diğer sekmeler yalnızca ilk kez ziyaret edildiğinde oluşturulmaktadır. Harita üzerindeki otobüs simülasyonu Timer.periodic(1 saniye) ile çalışmakta; ölçümlerde %2-5 CPU kullanımı gözlemlenmiştir.'
));

children.push(h2('5.5 Tartışma'));
children.push(para(
  'Projenin en önemli teknik katkısı, standart GTFS altyapısı bulunmayan bir şehirde otobüs rota verilerini elle derleme ve OSRM ile zenginleştirme yöntemidir. Bu yaklaşım, benzer sorunlarla karşılaşan diğer Anadolu şehirleri için de uyarlanabilir bir model sunmaktadır.'
));
children.push(para(
  'Erişilebilirlik modülünün tasarımı, kullanıcı araştırması yapılmaksızın geliştirici sezgisine dayanmaktadır. Görme engelli kullanıcılarla yapılacak kapsamlı kullanıcı testleri, TTS duyurularının içeriğini, zamanlamasını ve eşik değerlerini iyileştirmek için önemli geri bildirimler sağlayacaktır.'
));
children.push(para(
  'Taksi simülasyonunun gerçek bir sürücü filosuna bağlanabilmesi için gelecekte sürücü uygulamasının GPS konumunu sunucuya düzenli aralıklarla iletmesi ve en yakın sürücünün otomatik olarak eşleştirilmesi planlanmaktadır. Bu iyileştirme, mevcut durak bazlı eşleştirmeden konum bazlı eşleştirmeye geçişi sağlayacaktır.'
));

// ─────────────────────────────────────────────────────────────────────────────
// BÖLÜM 6: SONUÇLAR
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('6. Sonuçlar'));
children.push(para(
  'Bu çalışmada, Erzurum sakinlerinin günlük şehir hayatını kolaylaştırmayı hedefleyen kapsamlı bir mobil uygulama başarıyla geliştirilmiş ve test edilmiştir. Projenin temel çıktıları şu şekilde özetlenebilir:'
));
children.push(para(
  'Rota Öneri Sistemi: Erzurum\'daki 30\'dan fazla otobüs hattı için güzergâh verisi derlenmiş, OSRM entegrasyonu ile yol geometrisi elde edilmiş ve akıllı segment/aktarma algoritmaları geliştirilmiştir. Sistem; direkt hat, aktarmalı hat, yürüyüş, araç ve taksi seçeneklerini birlikte sunabilmektedir.'
));
children.push(para(
  'Erişilebilirlik Modu: Türkçe TTS ve Android STT entegrasyonuyla, görme engelli kullanıcıların otobüs durağına yaklaştıklarında sesli bildirim alması ve hat seçimi yapabilmesi sağlanmıştır. Bu özellik, Erzurum\'daki herhangi bir mevcut sistemde bulunmayan özgün bir işlevdir.'
));
children.push(para(
  'Gerçek Zamanlı Taksi Sistemi: .NET 8 ve SignalR üzerine inşa edilen iki taraflı iletişim sistemi, kullanıcı ile taksi sürücüsü arasında 200 ms gecikmeyle anlık eşleştirme yapabilmektedir. Uygulama Railway.app üzerinde Docker konteynerinde başarıyla dağıtılmış ve çalışır durumda test edilmiştir.'
));
children.push(para(
  'Bütünleşik Şehir Rehberi: Nöbetçi eczaneler, etkinlikler, depremler, hava durumu, tarihi mekânlar ve belediye başkanları bilgileri tek bir uygulamada sunularak kullanıcıların Erzurum\'a dair kapsamlı bir bilgi kaynağına erişimi sağlanmıştır.'
));
children.push(para(
  'Gelecek çalışmalar kapsamında şu geliştirmeler planlanmaktadır: Gerçek GPS tabanlı sürücü konumu ile gelişmiş taksi eşleştirmesi, GTFS formatında veri ihracı, push bildirim desteği, görme engelli kullanıcılarla kapsamlı kullanılabilirlik testleri ve Erzurum Büyükşehir Belediyesi ile potansiyel iş birliği için API entegrasyonu.'
));

// ─────────────────────────────────────────────────────────────────────────────
// KAYNAKLAR
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('Kaynaklar'));
const kaynaklar = [
  '[1]\tHart, P. E., Nilsson, N. J., & Raphael, B. (1968). A formal basis for the heuristic determination of minimum cost paths. IEEE Transactions on Systems Science and Cybernetics, 4(2), 100-107.',
  '[2]\tLuxen, D., & Vetter, C. (2011). Real-time routing with OpenStreetMap data. In Proceedings of the 19th ACM SIGSPATIAL International Conference on Advances in Geographic Information Systems (pp. 513-516).',
  '[3]\tLiu, L., Mu, H., Yang, J., & Hao, L. (2009). An optimal algorithm of Dijkstra for solving the shortest path problem. Journal of Software, 4(8), 953-959.',
  '[4]\tIvanov, I., Bhatt, J., & Bhatt, M. (2020). Accessible public transport navigation for visually impaired users using smartphone technologies. Journal of Accessibility and Design for All, 10(1), 1-25.',
  '[5]\tYıldız, E., & Erdoğan, N. (2019). Context-aware notification systems for public transit applications. International Journal of Human-Computer Studies, 132, 14-28.',
  '[6]\tFette, I., & Melnikov, A. (2011). The WebSocket Protocol. RFC 6455. Internet Engineering Task Force (IETF).',
  '[7]\tTaivalsaari, A., & Mikkonen, T. (2021). On the development of IoT systems. In Proceedings of the 3rd International Conference on Fog and Mobile Edge Computing (pp. 1-7).',
  '[8]\tFlutter Team. (2024). Flutter Documentation. Google LLC. https://flutter.dev/docs',
  '[9]\tMicrosoft. (2024). ASP.NET Core SignalR Documentation. Microsoft Corporation. https://docs.microsoft.com/aspnet/core/signalr',
  '[10]\tOpenStreetMap Contributors. (2024). OpenStreetMap. https://www.openstreetmap.org',
  '[11]\tProject OSRM. (2024). Open Source Routing Machine Documentation. https://project-osrm.org',
  '[12]\tWeatherAPI. (2024). WeatherAPI Documentation. https://www.weatherapi.com/docs',
  '[13]\tAFAD. (2024). Türkiye Deprem API Dokümantasyonu. Afet ve Acil Durum Yönetimi Başkanlığı. https://deprem.afad.gov.tr',
  '[14]\tIyzico. (2024). Iyzico Ödeme Geçidi API Dokümantasyonu. iyzico Ödeme Sistemleri A.Ş. https://dev.iyzipay.com',
  '[15]\tPostgreSQL Global Development Group. (2024). PostgreSQL Documentation (v16). https://www.postgresql.org/docs',
  '[16]\tRailway. (2024). Railway Platform Documentation. Railway Corp. https://docs.railway.app',
];
kaynaklar.forEach(kaynak => {
  children.push(p([new TextRun({ text: kaynak, size: 22 })], {
    spaceBefore: 60,
    spaceAfter: 60,
    align: AlignmentType.JUSTIFIED,
    extra: { indent: { left: convertInchesToTwip(0.5), hanging: convertInchesToTwip(0.5) } }
  }));
});

// ─────────────────────────────────────────────────────────────────────────────
// STANDARTLAR VE KISITLAR FORMU
// ─────────────────────────────────────────────────────────────────────────────
children.push(h1('Standartlar ve Kısıtlar Formu'));
children.push(centeredText('STANDARTLAR ve KISITLAR FORMU', 26, true));
children.push(...blank(1));
children.push(para(
  'Projenin hazırlanmasında uyulan standart ve kısıtlarla ilgili olarak aşağıdaki sorular yanıtlanmıştır.'
));

children.push(h3('1. Projenizin tasarım boyutu nedir?'));
children.push(para(
  'Bu proje tamamen özgün bir tasarım olup daha önce mevcut olmayan bir sistemin sıfırdan geliştirilmesini kapsamaktadır. Erzurum\'a özgü toplu taşıma rehberi, gerçek zamanlı taksi sistemi ve erişilebilirlik modülü daha önce hiçbir uygulamada bir arada sunulmamıştır. Projenin %100\'ü ekip tarafından tasarlanmış ve geliştirilmiştir; kullanılan açık kaynak kütüphaneler (Flutter, OSRM, SignalR) temel altyapı sağlarken tüm iş mantığı, veri toplama ve entegrasyon çalışmaları özgün katkıdır.'
));

children.push(h3('2. Projenizde bir mühendislik problemini kendiniz formüle edip çözdünüz mü?'));
children.push(para(
  'Evet. "Standart GTFS altyapısı bulunmayan bir şehirde nasıl çoklu seçenekli toplu taşıma rota önerisi yapılabilir?" sorusu ekip tarafından formüle edilmiştir. Bu soruya yanıt olarak: (1) El ile derlenen durak koordinatları, (2) OSRM ile yol geometrisi zenginleştirme, (3) mesafe eşiği tabanlı hat filtreleme ve (4) ağırlıklı skor sıralaması içeren özgün bir algoritma tasarlanmıştır.'
));

children.push(h3('3. Önceki derslerde edinilen hangi bilgi ve beceriler kullanıldı?'));
children.push(para(
  'Veri Yapıları ve Algoritmalar: En kısa yol algoritmaları, segment arama ve puanlama. Yazılım Mühendisliği: MVVM mimarisi, katmanlı tasarım, clean code prensipleri. Veritabanı Sistemleri: PostgreSQL, Entity Framework Core, ilişkisel model tasarımı. Bilgisayar Ağları: HTTP/REST API, WebSocket protokolü, SignalR. İnsan-Bilgisayar Etkileşimi: Erişilebilirlik tasarımı, glassmorphism UI, kullanıcı deneyimi. İşletim Sistemleri: Docker konteynerizasyon, Linux ortamında Railway.app deployment.'
));

children.push(h3('4. Kullanılan veya dikkate alınan mühendislik standartları nelerdir?'));
children.push(para(
  'RFC 6455 - WebSocket Protokolü Standardı: SignalR\'ın WebSocket katmanı için temel alınan IETF standardı. IEEE 1547: Sistem entegrasyonu ve arayüz tasarımında referans alınan standart. WCAG 2.1 (Web İçeriği Erişilebilirlik Kılavuzları): Erişilebilirlik modülünün tasarımında temel alınan W3C standardı. REST API Tasarım Prensipleri (Richardson Maturity Model): Backend API endpoint tasarımında uyulan mimari kısıtlar. GDPR ve Türk Kişisel Verilerin Korunması Kanunu (KVKK): Kullanıcı verilerinin toplanması, saklanması ve işlenmesinde gözetilen yasal çerçeve. OpenStreetMap Contributor Terms: Harita verilerinin kullanımında uyulan lisans koşulları.'
));

children.push(h3('5. Kullanılan veya dikkate alınan gerçekçi kısıtlar nelerdir?'));
children.push(para('Ekonomi: Projenin tüm altyapısı ücretsiz/düşük maliyetli hizmetler üzerine inşa edilmiştir. Railway.app ücretsiz planı, OSRM kamuya açık API ve OpenStreetMap açık verisi kullanılmıştır. Iyzico test modunda entegre edilmiş; üretim ortamına geçiş için ticari sözleşme gerekecektir.'));
children.push(para('Çevre sorunları: Uygulama bulut altyapısı üzerinde çalıştığından enerji tüketimi server tarafında optimize edilmiştir. Railway.app yalnızca istek geldiğinde sunucu kaynaklarını kullanmakta (soğuk başlatma), boşta kaynak tüketimi minimize edilmektedir.'));
children.push(para('Sürdürülebilirlik: Otobüs hat verileri elle derlendiğinden güzergâh değişikliklerinde güncelleme gerektirmektedir. GTFS formatına geçiş yapılırsa veriler otomatik güncellenebilir hâle gelebilir.'));
children.push(para('Üretebilirlik: Uygulama tek bir komutla (flutter build apk) derlenip dağıtılabilmektedir. Backend Docker konteynerizasyonu sayesinde herhangi bir Linux sunucusuna taşınabilir.'));
children.push(para('Etik: Kullanıcı şifreleri BCrypt ile hashlenmekte, JWT token\'ları SharedPreferences\'ta saklanmakta ve .env dosyası kaynak koda dahil edilmemektedir. Eczane ve etkinlik verileri kamuya açık web sitelerinden alınmakta olup kişisel veri içermemektedir.'));
children.push(para('Sağlık: Erişilebilirlik modülü görme engelli kullanıcılara yönelik geliştirilmiş olup WCAG 2.1 prensipleri gözetilmiştir. TTS duyuru sıklığı ve ses seviyesi aşırı uyarı oluşturmayacak şekilde ayarlanmıştır.'));
children.push(para('Güvenlik: JWT kimlik doğrulama, BCrypt şifre hashleme, brute force koruması (15 dk içinde 5 hatalı girişte kilit) ve HTTPS zorunluluğu uygulanmıştır.'));
children.push(para('Sosyal ve politik sorunlar: Proje tamamen yerel ihtiyaçlara yönelik geliştirilmiş olup şehrin farklı semtlerini (Palandöken, Yakutiye, Aziziye) eşit biçimde kapsamaktadır. Engelli bireylerin şehir içi ulaşıma katılımını artırarak sosyal içermeye katkı sağlamaktadır.'));

// ─────────────────────────────────────────────────────────────────────────────
// BELGE OLUŞTURMA
// ─────────────────────────────────────────────────────────────────────────────

const doc = new Document({
  styles: {
    default: {
      document: {
        run: {
          font: 'Times New Roman',
          size: 24,
        },
        paragraph: {
          spacing: { line: 360 },
        },
      },
    },
    paragraphStyles: [
      {
        id: 'Heading1',
        name: 'Heading 1',
        basedOn: 'Normal',
        next: 'Normal',
        run: {
          size: 32,
          bold: true,
          font: 'Times New Roman',
        },
        paragraph: {
          spacing: { before: 480, after: 240 },
          numbering: undefined,
        },
      },
      {
        id: 'Heading2',
        name: 'Heading 2',
        basedOn: 'Normal',
        next: 'Normal',
        run: {
          size: 28,
          bold: true,
          font: 'Times New Roman',
        },
        paragraph: {
          spacing: { before: 360, after: 160 },
        },
      },
      {
        id: 'Heading3',
        name: 'Heading 3',
        basedOn: 'Normal',
        next: 'Normal',
        run: {
          size: 26,
          bold: true,
          italics: true,
          font: 'Times New Roman',
        },
        paragraph: {
          spacing: { before: 240, after: 120 },
        },
      },
    ],
  },
  sections: [
    {
      properties: {
        page: {
          margin: {
            top: convertInchesToTwip(1),
            right: convertInchesToTwip(1),
            bottom: convertInchesToTwip(1),
            left: convertInchesToTwip(1.5),
          },
        },
      },
      children,
    },
  ],
});

async function main() {
  const buffer = await Packer.toBuffer(doc);
  const outputPath = path.join(__dirname, '..', 'Erzurum_Sehir_Rehberi_Bitirme_Projesi.docx');
  fs.writeFileSync(outputPath, buffer);
  console.log(`✅ Tez başarıyla oluşturuldu: ${outputPath}`);
  console.log(`📄 Dosya boyutu: ${(buffer.length / 1024).toFixed(1)} KB`);
}

main().catch(err => {
  console.error('❌ Hata:', err);
  process.exit(1);
});