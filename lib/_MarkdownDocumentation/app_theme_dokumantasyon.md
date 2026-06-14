# app_theme.dart — Tema Sistemi Dokümantasyonu

`lib/config/app_theme.dart`

---

## Nedir, Ne İşe Yarar?

Flutter uygulamasının tüm görsel dilini tek bir dosyadan yönetir.  
`MaterialApp`'te `theme: AppTheme.light` olarak bağlandığında, uygulamadaki her
`ElevatedButton`, `TextField`, `Dialog`, `Tooltip` vb. widget **otomatik olarak** bu
stilleri alır — her widget'a tek tek renk/stil yazmak gerekmez.

```dart
// main.dart
MaterialApp(
  theme: AppTheme.light,        // ← tek satır, tüm uygulamayı etkiler
  themeMode: ThemeMode.light,
  home: const HomePage(),
)
```

Dark tema kaldırılmış, uygulama yalnızca `light` modda çalışıyor.

---

## Çalışma Sistemi

### Material 3 + Seed Renk

```
_seedColor = #5B9BD5  (yumuşak Win11 mavisi)
        ↓
ColorScheme.fromSeed(...)
        ↓
primary, secondary, surface, error, outline...
tüm renk rolleri otomatik türetilir
```

`fromSeed` 40+ renk rolü üretir. Bunlar `Theme.of(context).colorScheme.primary`
gibi erişilir. `copyWith(...)` ile 4 rol override edilmiş:

| Override | Değer | Neden |
|---|---|---|
| `surface` | `#F9F9F9` | Win11 cam efekti benzeri beyaz |
| `surfaceContainerHighest` | `#F3F3F3` | Hafif gri yüzeyler |
| `outline` | `#E0E0E0` | Soft kenarlık |
| `outlineVariant` | `#EEEEEE` | Daha soluk kenarlık |

---

## Bileşen Haritası

### AppBar

```
backgroundColor : #F9F9F9  (şeffaf görünüm)
foregroundColor : #1F1F1F  (koyu metin)
elevation       : 0         (gölgesiz, Win11 flat)
scrolledUnder   : 1         (scroll'da hafif gölge)
centerTitle     : false     (sol hizalı başlık)
titleTextStyle  : 16px, w600, #1F1F1F
```

**Uygulama etkisi:** `DrawingCanvasPage` AppBar'ı, `HomePage` AppBar'ı —
her ikisi de bu temadan renk/font alır.

---

### ElevatedButton

```
backgroundColor : #5B9BD5  (seed mavi)
foregroundColor : white
elevation       : 0
padding         : 20h × 12v
borderRadius    : 6px
font            : 14px, w500
```

**Uygulama etkisi:** `showDialog` içindeki "Ekle", "Kaydet", "Uygula"
butonları. `SectionEditorDialog`'daki "Uygula" butonu kısmen override ediyor
(accent rengi dinamik).

**Senaryo tablosu:**

| Buton durumu | Görünüm |
|---|---|
| Normal | `#5B9BD5` arka plan, beyaz yazı |
| Hover/Pressed | Material 3 ripple + hafif koyulaşma |
| Disabled | `Colors.grey.shade300` (tema tarafından) |
| Override ile | `backgroundColor: Colors.red` → tema rengi geçersiz |

---

### OutlinedButton

```
foregroundColor : #1F1F1F
border          : #E0E0E0 (outline token)
padding         : 20h × 12v
borderRadius    : 6px
elevation       : 0
```

Uygulamada 7 yerde kullanılıyor. Çoğu iptal/geri butonları.

---

### TextButton

```
foregroundColor : #5B9BD5
padding         : 12h × 8v
font            : 14px, w500
```

Uygulamada 30 yerde kullanılıyor. Dialog "İptal" butonları, navigasyon linkleri.

---

### AlertDialog / Dialog

```
backgroundColor : #FCFCFC
elevation       : 4
borderRadius    : 8px
titleTextStyle  : 18px, w600, #1F1F1F
```

**Uygulama etkisi:** `_showAttachPanelDialog`, `MeasureDialog`,
`DeleteElementsDialog`, `SectionEditorDialog` (Dialog modu) — tümü bu stili miras alır.

**Not:** `SectionEditorDialog` bottom sheet olarak açıldığında (`showSliding`)
bu tema aktif değildir — `ClipRRect + Container` kullandığı için
`Theme.of(context).colorScheme.surface`'i alır.

---

### TextField / Input

```
fillColor       : #F3F3F3
borderRadius    : 4px
enabledBorder   : #E0E0E0
focusedBorder   : #5B9BD5, 1.5px
contentPadding  : 12h × 10v
hintStyle       : #999999, 14px
```

**Uygulama etkisi:** `MeasureDialog` içindeki ölçü girişleri,
`_showAttachPanelDialog` içindeki genişlik/yükseklik alanları.

**Önemli:** `SectionEditorDialog` içindeki TextField'lar bu temayı KULLANMIYOR —
hepsi `InputDecoration` ile manuel olarak stillendirilmiş. Bu bir tutarsızlık.

---

### Card

```
elevation : 0
color     : #F9F9F9
border    : #E8E8E8
radius    : 8px
```

Uygulamada 6 yerde kullanılıyor.

---

### ListTile

```
borderRadius : 6px
padding      : 16h × 4v
iconColor    : #5B9BD5
```

Uygulamada 4 yerde kullanılıyor (şekil listesi vb.).

---

### Chip

```
backgroundColor : #F0F0F0
selectedColor   : #E3F2FD
shape           : StadiumBorder (oval/pill)
labelStyle      : 12px, #1F1F1F
padding         : 8h × 4v
```

AppBar'daki zoom yüzdesi Chip'i bu temadan alıyor.

---

### Divider

```
color     : #EEEEEE
thickness : 1px
space     : 1px
```

Uygulamada 24 yerde kullanılıyor. Diyalog içi ayraçlar, panel bölücüler.

---

### Tooltip

```
backgroundColor : #2B2B2B @ 90%
textColor       : white
borderRadius    : 4px
padding         : 8h × 4v
font            : 12px
```

Toolbar butonlarındaki ipuçları bu stili alıyor (9 yerde).

---

### Typography

```
fontFamily : Roboto
```

| Token | Size | Weight | Renk |
|---|---|---|---|
| `displayLarge` | 28 | 600 | `#1F1F1F` |
| `displayMedium` | 24 | 600 | `#1F1F1F` |
| `displaySmall` | 20 | 600 | `#1F1F1F` |
| `titleLarge` | 18 | 600 | `#1F1F1F` |
| `titleMedium` | 16 | 500 | `#1F1F1F` |
| `bodyLarge` | 16 | 400 | `#1F1F1F` |
| `bodyMedium` | 14 | 400 | `#1F1F1F` |
| `bodySmall` | 12 | 400 | `#666666` |

---

## Uygulamaya Etki Haritası

```
AppTheme.light
│
├── MaterialApp
│   ├── HomePage
│   │   ├── AppBar          ← appBarTheme
│   │   ├── ListTile'lar    ← listTileTheme
│   │   └── ElevatedButton  ← elevatedButtonTheme
│   │
│   ├── DrawingCanvasPage
│   │   ├── AppBar          ← appBarTheme
│   │   ├── Tooltip'ler     ← tooltipTheme
│   │   ├── Chip (zoom %)   ← chipTheme
│   │   ├── Divider'lar     ← dividerTheme
│   │   └── showDialog'lar
│   │       ├── MeasureDialog        ← dialogTheme + inputTheme
│   │       ├── _showAttachPanel     ← dialogTheme + inputTheme
│   │       ├── DeleteElementsDialog ← dialogTheme
│   │       └── SectionEditorDialog
│   │           ├── Dialog modu      ← dialogTheme ✓
│   │           └── BottomSheet modu ← colorScheme.surface ✓
│   │               (TextField'lar hardcode) ✗
│   │
│   └── corner_side_panels, system_bottom_panel...
│       ← ElevatedButton, TextButton, OutlinedButton
```

---

## Renk Paleti Özeti

```
Birincil mavi   : #5B9BD5  → ElevatedButton, focusedBorder, iconColor
Koyu metin      : #1F1F1F  → AppBar başlık, genel metin
Gri metin       : #666666  → bodySmall, hint, label
Arka plan       : #F9F9F9  → surface, AppBar, Card
Gri yüzey       : #F3F3F3  → input fill, surfaceContainerHighest
Kenarlık        : #E0E0E0  → outline, button border, input border
Soft kenarlık   : #EEEEEE  → outlineVariant, divider
Tooltip bg      : #2B2B2B @ 90%
```

---

## Mevcut Tutarsızlıklar

### 1. Hardcode renkler — tema dışı kalan widget'lar

Uygulama genelinde 162+ yerde `Color(0xFF...)` veya `Colors.shade` ile
doğrudan renk yazılmış. Bunlar tema değiştiğinde güncellenmez.

En yaygın durumlar:

| Dosya | Sorun | Öneri |
|---|---|---|
| `drawing_canvas_page.dart` | Toolbar buton renkleri hardcode | `colorScheme.primary` kullan |
| `section_editor_dialog.dart` | TextField'lar manuel stillendirilmiş | Tema `inputDecorationTheme`'den faydalansın |
| `section_editor_dialog.dart` | `accent = Color(0xFF185FA5)` sabit | `Theme.of(context).colorScheme.primary` olabilir |
| `corner_side_panels.dart` | `Colors.blue`, `Colors.orange`, `Colors.teal` | Tema renklerine bağlanabilir |
| `system_bottom_panel.dart` | `Color(0xFF333333)` hardcode | `colorScheme.onSurface` |

### 2. `SectionEditorDialog` TextField tutarsızlığı

`SectionEditorDialog` içindeki TextField'lar, uygulamanın genel
`inputDecorationTheme`'ini (gri fill, mavi focus border) kullanmıyor.
Bunun yerine her alan için manuel `InputDecoration` yazılmış.
Bu görsel farklılık yaratıyor:
- Uygulama geneli: `fillColor: #F3F3F3`, `focusBorder: #5B9BD5`
- Diyalog içi: `fillColor: Colors.white`, `focusBorder: accent renk`

### 3. `visualDensity: comfortable`

Tüm widget'lar biraz daha "havadar" görünür. Bu özellikle
ListTile ve Button padding'ini etkiler. Tablet/masaüstü için uygundur.

---

## Tema Nasıl Genişletilir?

### Yeni bileşen eklemek

```dart
// app_theme.dart içine ekle:
switchTheme: SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? const Color(0xFF5B9BD5) : null,
  ),
),
```

### Rengi merkezi değiştirmek

```dart
// Tek satır değişiklik → tüm uygulamayı etkiler:
static const Color _seedColor = Color(0xFF2E7D32); // yeşile geç
```

### Dark tema eklemek

```dart
static final ThemeData dark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ),
  // ... diğer overrides
);
```

```dart
// main.dart'ta:
darkTheme: AppTheme.dark,
themeMode: ThemeMode.system, // veya kullanıcı tercihi
```

---

## Özet

`AppTheme.light` tek noktadan kontrol sağlar:
- **55** ElevatedButton, **30** TextButton, **17** Dialog, **21** TextField,
  **9** Tooltip, **24** Divider otomatik olarak bu stili alıyor.
- Seed renk sistemi sayesinde tek renk değişikliği tüm UI'yi günceller.
- Mevcut sorun: kendi yazdığımız diyalog/panel widget'larında
  hardcode renkler kullanılıyor; bunlar temadan bağımsız kalıyor.
