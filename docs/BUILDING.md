# Building

Android is the currently tested target. This legacy Flutter codebase builds without sound null safety.

## Requirements

- Flutter compatible with `pubspec.yaml`
- Android SDK with compile SDK 33
- Compatible Java, Gradle, and Android NDK toolchains
- KDF static libraries for each target architecture

Place trusted KDF libraries at:

```text
android/app/src/main/cpp/libs/arm64-v8a/libmm2.a
android/app/src/main/cpp/libs/armeabi-v7a/libmm2.a
```

Do not commit these large generated binaries.

## Validate and build

```sh
flutter pub get
flutter test test/simple_dex_order_contract_test.dart
flutter build apk --debug
unzip -t build/app/outputs/flutter-apk/app-debug.apk
sha256sum build/app/outputs/flutter-apk/app-debug.apk
```

A production APK must be built with `flutter build apk --release` and signed using private material stored outside the repository. Never commit keystores, passwords, or `key.properties`.

The tested coin configuration is `assets/coins_config_tcp.json`, derived from [KomodoPlatform/coins](https://github.com/KomodoPlatform/coins). Any update requires renewed activation, Electrum, market, and swap testing.
