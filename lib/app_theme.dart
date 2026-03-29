library; // Bu dosyanın bir Dart kütüphanesi olduğunu belirtir. Projede import ile kullanılmasını sağlar.

import 'package:flutter/material.dart'; // Flutter'ın Material bileşenleri ve ThemeData, ColorScheme vb. için gerekli paket.

class AppTheme {
  // ----- Tema için kullanılacak sabit tohum rengi (seed color) -----
  // Material 3'te renk paletini otomatik türetmek için bir "seed" (tohum) rengimiz olur.
  // Burada önceki temadaki mavi tonuna yakın, sabit bir Color kullanıyoruz.
  static const Color _seedColor = Color(
    0xFF1565C0,
  ); // Colors.blue[800] yaklaşık değeri.

  // -------------------- Açık (Light) Tema --------------------
  static final ThemeData light = ThemeData(
    // Material 3'ü etkinleştirir. Bu, yeni bileşen stilleri ve renk/tipografi yaklaşımlarını kullanır.
    useMaterial3: true,

    // Material 3'ün önerdiği şekilde "seed" renginden bir ColorScheme oluşturuyoruz.
    // brightness: Brightness.light ile açık tema olduğunu belirtiyoruz.
    // copyWith ile bazı ana alanları (arka plan, surface, vs.) eskisinde olduğu gibi özelleştiriyoruz.
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ).copyWith(
          // Uygulama genel arka planı (örn. Scaffold arka planı) için beyaz kullan.
          onBackground: Colors.grey[800]!,
          // Kart ve yüzey rengi (surface) beyaz.
          surface: Colors.white,
          // Surface üstündeki yazı/ikon rengi.
          onSurface: Colors.grey[800]!,
          // Temel / primary rengi buraya özel koyuyoruz (istersek seed'in ürettiğinden farklı yapabiliriz).
          primary: Colors.grey[300]!,
          // primary üstündeki kontrast rengi (örn. primary arka plan üzerindeki ikon/başlık rengi).
          onPrimary: _seedColor,
          // İkincil renk (secondary) ve üstündeki yazı/ikon rengi.
          secondary: Colors.grey[500]!,
          onSecondary: Colors.grey[800]!,
        ),

    // Platforma göre görsel yoğunluğu (padding/spacing'leri hafif optimize eder).
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // -------------------- Yazı Tipi (Typography) --------------------
    // Uygulama genelinde kullanılacak metin stillerini tanımlıyoruz.
    // Material 3 ile gelmiş Typography stilleri kullanılabilir; burada mevcut TextTheme'i koruyup
    // açık ve anlaşılır boyutlar/rengeler atıyoruz.
    textTheme: TextTheme(
      // Büyük başlık/Display için stil
      displayLarge: TextStyle(
        fontSize: 24.0, // piksel cinsinden metin boyutu
        fontWeight: FontWeight.bold, // kalınlık: bold
        color: Colors.grey[800], // rengi koyu gri
      ),
      // Orta büyük başlık
      displayMedium: TextStyle(
        fontSize: 20.0,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
      // Küçük başlık
      displaySmall: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
      // Normal büyük gövde metni
      bodyLarge: TextStyle(fontSize: 16.0, color: Colors.grey[800]),
      // Normal gövde metni
      bodyMedium: TextStyle(fontSize: 14.0, color: Colors.grey[800]),
      // Küçük metin (örn. yardımcı/ek bilgi)
      bodySmall: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
      // Orta boy başlık/başlıkçık (title)
      titleMedium: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w500,
        color: Colors.grey[800],
      ),
      // Küçük başlıkçık
      titleSmall: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
    ),

    // -------------------- AppBar (Üst Çubuk) Teması --------------------
    appBarTheme: AppBarTheme(
      // Başlığı ortala (Android / iOS tutarlılığı için)
      centerTitle: true,
      // AppBar gölgesi yüksekliği
      elevation: 2,
      // Kaydırma altındayken (scrolledUnder) daha yüksek gölge
      scrolledUnderElevation: 4,
      // AppBar arka planı — açık tema için beyaz
      backgroundColor: Colors.white,
      // AppBar içindeki metin ve ikonların rengi
      foregroundColor: Colors.grey[800]!,
      // Başlık için özel metin stili
      titleTextStyle: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    ),

    // -------------------- ElevatedButton (Yükseltilmiş Buton) Teması --------------------
    // Material 3'te ElevatedButton görünümü yeni tasarım kurallarına göre değişse de,
    // burada stil ayarlarını ButtonStyle veya styleFrom ile veriyoruz.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Buton arka plan rengi
        backgroundColor: Colors.grey[300],
        // Buton üzerindeki yazı/ikon rengi
        foregroundColor: _seedColor,
        // Yazı tipi boyutu ve ağırlığı
        textStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
        // İç dolgu (padding)
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // Köşe yuvarlatma
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // Minimum buton boyutu (genişlik, yükseklik)
        minimumSize: Size(200, 62),
      ),
    ),

    // -------------------- TextButton (Yazı Butonu) Teması --------------------
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // Metin rengi
        foregroundColor: _seedColor,
        // Metin stili
        textStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
      ),
    ),

    // -------------------- OutlinedButton (Çerçeveli Buton) Teması --------------------
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // Çerçeve ve metin rengi
        foregroundColor: _seedColor,
        side: BorderSide(color: _seedColor),
        // Metin stili
        textStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
        // İç dolgu
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // Köşe yuvarlatma
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // -------------------- Card Teması --------------------
    // Kart bileşenleri için genel görünüm
    cardTheme: CardThemeData(
      // Kart gölgesi (elevation)
      elevation: 2,
      // Kart arka plan rengi
      color: Colors.white,
      // Kartın şekli (yuvarlatılmış köşeler)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // -------------------- Dialog (Açılır Pencere) Teması --------------------
    dialogTheme: DialogThemeData(
      // Dialog gölgesi
      elevation: 4,
      // Dialog arka plan rengi
      backgroundColor: Colors.white,
      // Köşe yuvarlatma
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Başlık metin stili
      titleTextStyle: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
      // İçerik metin stili
      contentTextStyle: TextStyle(fontSize: 14.0, color: Colors.grey[800]),
    ),

    // -------------------- Input (TextField vb.) Teması --------------------
    inputDecorationTheme: InputDecorationTheme(
      // Varsayılan border (çerçeve)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      // Etkin olmayan durumdaki border
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      // Odaklanmış (focus) border
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _seedColor),
      ),
      // Hata durumundaki border
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      // Odaklı hata border
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      // Arka plan doldurulsun mu (TextField içini doldurma)
      filled: true,
      // Doldurma rengi (hafif gri)
      fillColor: Colors.grey[50],
      // Label (etiket) stil rengi
      labelStyle: TextStyle(color: Colors.grey[700]),
      // Hint (örnek metin) stili
      hintStyle: TextStyle(color: Colors.grey[500]),
      // İçerik padding (metin ve ikon arasındaki boşluk)
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      // Prefix icon rengi (örn. TextField içindeki ikon)
      prefixIconColor: Colors.grey[600],
    ),

    // -------------------- Divider (Bölücü) Teması --------------------
    dividerTheme: DividerThemeData(
      // Bölücü rengi
      color: Colors.grey[300],
      // Kalınlık
      thickness: 1,
      // Boşluk (üst-alt)
      space: 1,
    ),
  );

  // -------------------- Koyu (Dark) Tema --------------------
  static final ThemeData dark = ThemeData(
    // Material 3 modunu açık tutuyoruz (koyu olarak çalışacak şekilde)
    useMaterial3: true,

    // Koyu tonlarda bir ColorScheme oluşturuyoruz. seedColor aynı tutuldu, brightness dark.
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          // Koyu tema için arka plan çok koyu gri
          surface: Colors.grey[900],
          // Arka plan üstündeki yazı için açık gri
          onSurface: Colors.grey[300],
          // Primary için koyu gri ton
          primary: Colors.grey[700],
          // Primary üstü için daha açık mavi tonu (kontrast)
          onPrimary: Colors.blue[200]!,
        ),

    // Platforma göre görsel yoğunluk
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // AppBar için temel ayarlar (renkleri colorScheme'den alır; ekstra detay eklenebilir)
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 2,
      scrolledUnderElevation: 4,
      // Not: arka plan ve foreground explicit verilmezse colorScheme'e göre alınır.
    ),

    // Card tema (koyu temaya uygun şekil ve gölge)
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Dialog tema (koyu temada şekil, yükseklik vb.)
    dialogTheme: DialogThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
