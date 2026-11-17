# Building Vector

All commands run from the `app/` folder. Flutter 3.50.0 (stable) was used.

```
cd app
flutter pub get
flutter test
```

## What has actually been tested

| Platform | Status | How |
| --- | --- | --- |
| Linux desktop | **Built and run** in a Linux cloud container (Ubuntu, virtual screen), driven by the simulator: HUD, track, recovery, history, export, replay, settings surviving a restart. **Not yet run on Beckett's Fedora machine.** | `flutter build linux --debug` |
| App tests | 60 tests pass (`flutter test`), including every protocol test vector, the sample-flight stats, and the byte-exact CSV | `python scripts/check.py` |
| Android | **Not tested** | see below |
| iPhone / iPad | **Not tested** (needs a Mac) | see below |
| macOS | **Not tested** (needs a Mac) | see below |
| Windows | **Not tested** (needs a Windows PC) | see below |
| Web (Chrome) | **Not supported yet**: flights are saved as files, which browsers cannot do; not tested | |

Only move a platform to "tested" after someone has run it on a real device.

## Linux (Fedora)

One-time packages (Fedora names, from Flutter's Linux page; not yet run on Fedora):

```
sudo dnf install git curl unzip xz zip which file mesa-libGLU clang cmake ninja-build pkgconf-pkg-config gtk3-devel
```

Run or build:

```
flutter run -d linux
flutter build linux --release
```

The release app is in `build/linux/x64/release/bundle/` (run `./vector`).

## Android

Needs Android Studio (for the SDK) and a phone with USB debugging, or an emulator.

```
flutter run -d android
flutter build apk --release
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Already set: INTERNET permission and plain
`ws://` allowed (`usesCleartextTraffic`), needed to reach the ground node. Untested.

## iPhone and iPad

Needs a Mac with Xcode, and an Apple developer account (about $99/year) to install on other people's devices (TestFlight).

```
flutter run -d ios
flutter build ipa
```

Already set in `ios/Runner/Info.plist`: the Local Network permission text and App Transport Security
allowing plain `ws://` on the local network. Untested.

## macOS

```
flutter run -d macos
flutter build macos --release
```

Already set: the sandbox "outgoing network connections" entitlement. Untested.

## Windows

Needs Visual Studio with "Desktop development with C++".

```
flutter run -d windows
flutter build windows --release
```

Untested.

## Firmware (native tests, no hardware)

```
pip install platformio
cd firmware
pio test -e native
```

Expect two test suites: `test_packet` (7 tests) and `test_phase` (6 tests). Not yet run under real PlatformIO.
