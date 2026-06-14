# main.dart — Uygulama Başlangıcı ve Hata Yönetim Sistemi

İlgili dosyalar:
- `lib/main.dart`
- `lib/services/error_handler.dart`
- `lib/services/app_exceptions.dart`
- `lib/services/result.dart`
- `lib/shared/widgets/app_error_widget.dart` *(ErrorBoundary + AppErrorWidget)*

---

## main.dart Nedir, Ne Yapar?

Flutter uygulamasının tek giriş noktasıdır. İki görevi var:

1. **Uygulamayı başlatır** — `ProviderScope` ile Riverpod'u sararlar,
   `WinDesignApp`'i çalıştırır.
2. **Global hata ağını kurar** — uygulama çalışmadan önce üç katmanlı
   hata yakalama mekanizmasını devreye sokar.

```
main()
 ├── runZonedGuarded(...)       ← 1. katman: async + dart:isolate hataları
 │    ├── ensureInitialized()
 │    ├── _setupGlobalErrorHandling()
 │    │    ├── FlutterError.onError    ← 2. katman: Flutter framework hataları
 │    │    └── PlatformDispatcher.onError ← 3. katman: platform/native hataları
 │    └── runApp(ProviderScope → WinDesignApp)
 └── (error, stack) → ErrorHandlerService  ← 1. katman yakalama
```

---

## Üç Hata Yakalama Katmanı

### Katman 1 — `runZonedGuarded`

```dart
runZonedGuarded(
  () { /* uygulama */ },
  (error, stackTrace) { ErrorHandlerService().handleError(...) },
);
```

**Yakalar:**
- `async`/`await` içinde fırlatılan hatalar
- `Future` zincirlerinde yakalanmayan hatalar
- `Timer`, `Stream` callback hatalar
- Dart izolat hataları

**Yakalamazlar:** Flutter widget ağacı hataları (bunu Katman 2 yapar).

**`showUserMessage: false`** — zone hataları kritik olabilir,
kullanıcıya ham hata göstermek yerine sadece loglanıyor.

---

### Katman 2 — `FlutterError.onError`

```dart
FlutterError.onError = (details) {
  ErrorHandlerService().handleError(
    error: details.exception,
    context: 'FLUTTER_ERROR',
    ...
  );
};
```

**Yakalar:**
- `build()` metodundaki widget hataları
- `RenderObject` hataları
- `setState` sonrası layout hataları
- Flutter'ın kendi uyarı/hataları

Debug modunda Flutter bunları zaten gösterir.
Bu hook sayesinde release modunda da loglanır.

---

### Katman 3 — `PlatformDispatcher.instance.onError`

```dart
PlatformDispatcher.instance.onError = (error, stackTrace) {
  ErrorHandlerService().handleError(...);
  return true; // ← hata "işlendi" sinyali
};
```

**`return true`** kritik — `false` dönseydi uygulama crash olurdu.

**Yakalar:**
- Platform channel hataları (kamera, dosya sistemi vb.)
- `compute()` / ikincil izolat hataları
- Native plugin hataları

---

## ErrorHandlerService

Singleton pattern — tüm uygulama aynı instance'ı kullanır.

```dart
ErrorHandlerService()  // factory ile her çağrı aynı nesneyi döner
```

### İşlem Akışı

```
handleError(error, context, stackTrace, showUserMessage)
     │
     ├─ _getErrorLevel(error)     → seviye belirle
     ├─ _logError(...)            → dart:developer log()
     ├─ _showUserMessage(...)     → (şu an sadece print)
     └─ _reportError(...)         → CRITICAL/ERROR → _logToFile
```

### Hata Seviyeleri ve Eşleşmeleri

| Seviye | Emoji | Exception Türleri | Anlamı |
|---|---|---|---|
| `DEBUG` | 🐛 | — | Geliştirici notu |
| `INFO` | ℹ️ | `DatabaseNotFoundException` | Normal akış, kayıt yok |
| `WARNING` | ⚠️ | `DatabaseConstraintException`, `ValidationException`, `UIException` | Kullanıcı hatası |
| `ERROR` | ❌ | `NetworkException`, `SerializationException`, `DatabaseException`, `AppException` | Sistem hatası |
| `CRITICAL` | 💥 | Tanımsız tüm hatalar | Beklenmeyen durum |

**Kural:** `AppException` alt sınıfı olmayan her hata otomatik CRITICAL
sayılır. Dışarıdan gelen `StateError`, `TypeError`, `NoSuchMethodError` vb.
hepsi CRITICAL.

---

## AppException Hiyerarşisi

```
Exception (Dart)
└── AppException (abstract)
    ├── message: String
    ├── stackTrace: StackTrace?
    └── timestamp: DateTime
        │
        ├── DatabaseException
        │   ├── DatabaseNotFoundException   → INFO
        │   └── DatabaseConstraintException → WARNING
        │
        ├── NetworkException                → ERROR
        ├── ValidationException             → WARNING
        ├── SerializationException          → ERROR
        └── UIException                     → WARNING
```

### Kullanım Örneği

```dart
throw DatabaseNotFoundException('Proje bulunamadı: $projectId');
throw ValidationException('Genişlik 50mm\'den küçük olamaz');
throw SerializationException('ShapeSpec JSON parse hatası');
```

---

## Result<T, E> — Fonksiyonel Hata Yönetimi

`try/catch` yerine dönüş tipinde hata taşıma.

```dart
sealed class Result<T, E extends AppException>
  ├── Success<T, E>(value: T)
  └── Failure<T, E>(error: E)
```

### Kullanım Senaryoları

```dart
// Repository dönüş tipi
Future<Result<ShapeSpec, DatabaseException>> loadShape(String id);

// Çağıran taraf
final result = await repository.loadShape(id);
switch (result) {
  case Success(:final value):
    setState(() => shape = value);
  case Failure(:final error):
    ErrorHandlerService().handleError(error: error, context: 'LOAD_SHAPE');
}

// Veya kısa yol
final shape = result.dataOrThrow;  // başarısızsa fırlatır
final error = result.errorOrNull;  // başarısızsa Exception, değilse null

// Dönüşüm (map)
final nameResult = result.map((spec) => spec.toString());
```

### try/catch vs Result

| Yaklaşım | Avantajı | Dezavantajı |
|---|---|---|
| `try/catch` | Basit, okunabilir | Hata tipi derleme zamanında belli değil |
| `Result<T, E>` | Tip güvenli, zorlaştırır ihmal | Boilerplate artıyor |

Uygulama şu an ikisini karışık kullanıyor — repository katmanında
`Result`, UI katmanında `try/catch`.

---

## AppErrorWidget ve ErrorBoundary

### AppErrorWidget

Hata durumunda gösterilecek fallback UI:

```
┌─────────────────────────┐
│   [!] (gri ikon 64px)   │
│   Hata Oluştu           │
│   [mesaj metni]         │
│   [Tekrar Dene butonu]  │
└─────────────────────────┘
```

`Theme.of(context)` kullanıyor — tema uyumlu.
`onRetry` callback ile kurtarma aksiyonu alınabiliyor.

### ErrorBoundary

Widget ağacını korur — iç widget'ta oluşan hatayı kapsüller,
uygulamanın geri kalanını ayakta tutar.

```dart
ErrorBoundary(
  fallback: (error, stack) => AppErrorWidget(
    message: 'Çizim yüklenemedi',
    onRetry: () => ref.invalidate(drawingProvider),
  ),
  child: DrawingCanvasPage(...),
)
```

**Mevcut durum:** `ErrorBoundary` tanımlı ama uygulamada hiçbir yerde
kullanılmıyor. Widget ağacına hiç eklenmemiş.

---

## Senaryo Haritası

### Senaryo 1 — Veritabanı kaydı bulunamadı

```
repository.loadDrawing(id)
  └── throw DatabaseNotFoundException('...')
       └── ErrorHandlerService.handleError(...)
            ├── seviye: INFO
            ├── log: "ℹ️ INFO | DatabaseNotFoundException"
            └── showUserMessage: true
                 └── print("Kullanıcı: İstenilen veri bulunamadı")
```

→ Uygulama çalışmaya devam eder, kullanıcıya mesaj gösterilebilir.

---

### Senaryo 2 — Zone'da beklenmeyen hata (şu an yaşanan)

```
_DrawingCanvasPageState._openHorizontalForSource(...)
  └── firstWhere() → StateError: Bad state: No element
       └── Zone yakalıyor
            └── ErrorHandlerService.handleError(context: 'ZONE_ERROR')
                 ├── seviye: CRITICAL (StateError, AppException değil)
                 ├── log: "💥 CRITICAL | StateError"
                 └── _logToFile("Hata dosyaya kaydedildi: ZONE_ERROR")
```

→ Sadece loglanır, kullanıcıya bir şey gösterilmez (`showUserMessage: false`).

---

### Senaryo 3 — Validation hatası (doğru kullanım)

```dart
// Controller içinde:
if (gaps.any((g) => g < 50)) {
  throw ValidationException('Gap değeri 50mm\'den küçük olamaz');
}
```

```
ValidationException
  └── ErrorHandlerService
       ├── seviye: WARNING
       └── showUserMessage: true
            └── "Lütfen girdiğiniz bilgileri kontrol edin."
```

---

### Senaryo 4 — Flutter build hatası

```
DrawingCanvasPage.build()
  └── NullPointerException (null şekil çizimi)
       └── FlutterError.onError yakalıyor
            └── ErrorHandlerService(context: 'FLUTTER_ERROR')
                 ├── seviye: CRITICAL
                 └── _logToFile (kritik olduğu için)
```

---

## Mevcut Eksiklikler

### 1. `_showUserMessage` çalışmıyor

```dart
void _showUserMessage(dynamic error, String context) {
  print('👤 Kullanıcı Mesajı: $userMessage'); // ← sadece print
}
```

Kullanıcı hiçbir şey görmüyor. Gerçek SnackBar/Dialog entegrasyonu yok.
`BuildContext` olmadan SnackBar göstermek için `ScaffoldMessenger` + global
context gerekiyor.

**Öneri:**
```dart
// NavigatorKey ile global context:
final globalNavigatorKey = GlobalKey<NavigatorState>();

void _showUserMessage(dynamic error, String context) {
  final ctx = globalNavigatorKey.currentContext;
  if (ctx == null) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(_getUserFriendlyMessage(error, context))),
  );
}
```

---

### 2. `_logToFile` gerçek implementasyon yok

```dart
void _logToFile(...) {
  print('📁 Hata dosyaya kaydedildi: $context'); // ← sadece print
}
```

CRITICAL ve ERROR seviyeleri dosyaya kaydedilmesi gerekiyor.
**Öneri:** `path_provider` + `dart:io` ile gerçek dosya yazımı,
veya Crashlytics/Sentry entegrasyonu.

---

### 3. `ErrorBoundary` hiç kullanılmıyor

Tanımlı ama widget ağacında yok. `DrawingCanvasPage` veya kritik
widget'lar bu boundary içine alınmalı.

---

### 4. `isCriticalError` static metodu bağlantısız

```dart
static bool isCriticalError(dynamic error) { ... }
static String getErrorCode(dynamic error) { ... }
```

Uygulama içinde hiçbir yerde çağrılmıyor.

---

## Özet

`main.dart` + `ErrorHandlerService` birlikte sağlam bir hata yakalama
altyapısı kuruyor — üç katman (zone, Flutter, platform) her türlü hatayı
yakalıyor ve loglara düşürüyor. Altyapı hazır, ama son mil tamamlanmamış:
kullanıcıya mesaj gösterme, dosyaya yazma, ve `ErrorBoundary` kullanımı
henüz gerçek implementasyon bekliyor.
