Project: opnwndw — Flutter app

Quick context
- A minimal Flutter application (entry: `lib/main.dart`) that currently renders a basic "Hello World!" MaterialApp.
- Android native glue exists under `android/` and app module in `app/` inside Android directory; this is a standard Flutter Android embedding project.
- Dependencies are the Flutter SDK only (see `pubspec.yaml`).

How I should behave
- Prioritize small, self-contained changes (add a widget, fix build config, add a test) and always run `dart analyze` or `flutter analyze` before finalizing edits.
- When adding platform code, prefer editing files under `android/` (Kotlin) for Android and follow existing package `com.uekdesigner.opnwndw`.
- Preserve the minimal `pubspec.yaml` style and do not add unnecessary heavy dependencies without user approval.

Key files to read first
- `lib/main.dart` — app entry and primary UI scaffold.
- `pubspec.yaml` — dependency and Flutter configuration.
- `android/app/src/main/kotlin/com/uekdesigner/opnwndw/MainActivity.kt` — Android embedding and plugin registration.
- `README.md` — project description (minimal).

Patterns and conventions in this repo
- Very small, single-file UI in `lib/` — prefer adding new Dart files under `lib/` for feature growth.
- Use Material widgets (the app uses `MaterialApp` and `Scaffold`).
- Keep logic in Dart UI layer; there are no existing state-management libraries (do not introduce Bloc/Provider without discussing).

Build, test and debug notes
- Typical local dev commands (Windows PowerShell):
  - flutter pub get
  - flutter run -d <device>
  - flutter build apk (or `flutter build appbundle`)
- Use `flutter analyze` and `flutter test` to run static analysis and tests. The project currently has no tests; add minimal unit/widget tests under `test/` when required.

Integration and native considerations
- Android-specific configuration and resources live under `android/` and the app module under `app/`.
- Native code is Kotlin; modifications there should maintain package name `com.uekdesigner.opnwndw`.

When you cannot infer intent
- If a change affects app architecture (state management, routing, persistent storage), propose a brief design and wait for user approval.

Examples to reference
- Entry point: `lib/main.dart` — shows app structure and widget composition.
- Android main: `android/app/src/main/kotlin/com/uekdesigner/opnwndw/MainActivity.kt` — native entry-point for Android embedding.

If asked to add features
- Suggest lightweight, dependency-free approaches first (pure Dart/Flutter), then escalate to platform channels or packages only with explicit approval.

Questions to ask the repo owner early
- Intended product scope (single-screen demo vs full app).
- Preferred state-management strategy (setState only, Provider, Bloc, Riverpod).
- CI/CD preferences (GitHub Actions, code signing for Android).

End of file
