# MediaPager.App.Flutter

MediaPager is an open-source, self-hosted media platform by No Bugs Given. This app connects to your own MediaPager servers and gives you access to your personal media libraries, playback, server settings, and plugins on Android, iOS, macOS, Windows, and Linux. You can save multiple servers and choose which one opens by default.

The app's native screens are for managing server connections. The full MediaPager interface—including library browsing and playback—runs in an in-app platform WebView, so the server's responsive site handles its own layout.

## Connections

Each connection stores a nickname, server URL, and username/email. The password is used once with `/auth/mobile-sessions` and is not retained. The server returns an 8-hour access token and a rotating, revocable 90-day refresh token; the refresh token is stored with `flutter_secure_storage`. Profile details and the default connection ID are stored locally with `shared_preferences`. Profiles do not sync between devices.

On each connection, the app exchanges its refresh token at `/auth/mobile-sessions/refresh`, then seeds the returned MediaPager bearer token into that server's WebView local storage before loading the site. When a default server is configured, it opens automatically on app launch. Use the connection's menu on the server list to set or clear the default, edit, or remove a connection. Removing a saved connection revokes its app session; the Profile → Security page also lists app devices and requires confirmation plus the account password to revoke one.

HTTP is accepted for IP-literal server addresses and local names (`localhost`, `.local`, or single-label hostnames). Use HTTPS for public domain names.

Android builds target API 36 with a minimum API level of 24. iOS/iPadOS targets iOS 15 and later; iPad supports all orientations and resizable multitasking. macOS targets version 12 and later. App Store submission requires the current Apple SDK/Xcode version.

Release Android builds require a private `android/key.properties` and keystore (the generated `.gitignore` excludes them). Do not commit signing credentials. iOS signing and distribution are configured through Xcode with the No Bugs Given developer account.

## Run

```sh
flutter pub get
dart run icons_launcher:create
flutter run -d android
flutter run -d ios
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

The platform toolchains are required for native builds. Windows WebView uses the Microsoft Edge WebView2 Runtime. Linux needs WebKitGTK 4.1 and libsecret development/runtime packages (for example, `libwebkit2gtk-4.1-dev libsecret-1-dev libsecret-1-0` on Debian/Ubuntu).

## Verify

```sh
flutter analyze
flutter test
```
