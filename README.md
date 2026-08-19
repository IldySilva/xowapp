# XowCase

**XowCase** creates professional app demos and showcases with device frames.

Hybrid architecture: **Flutter** UI across macOS, Linux, and Web; **Swift/ScreenCaptureKit** for native macOS capture; browser **MediaRecorder** on Web; **FFmpeg** export on desktop.

---

## Features

- **Native screen & simulator capture** (macOS): displays, windows, and iOS Simulator via ScreenCaptureKit / `simctl`
- **Browser screen capture** (Web): record a tab/window with `getDisplayMedia`
- **Import video** (macOS / Linux / Web): edit existing recordings
- **Device frames**, crop, backgrounds, and export resolutions (16:9, 1:1, 3:4, …)
- **Desktop export** via FFmpeg (`h264_videotoolbox` on macOS, `libx264` on Linux)

---

## Platforms

| Platform | Capture | Edit | Framed FFmpeg export |
|----------|---------|------|----------------------|
| macOS    | Native  | Yes  | Yes                  |
| Linux    | Import  | Yes  | Yes (needs `ffmpeg`) |
| Web      | Browser screen + Import | Yes | Downloads source video (framed export on desktop) |

---

## Prerequisites

### All platforms
- **Flutter SDK** (stable) — Dart `^3.11.4`

### macOS
- Xcode
- FFmpeg: `brew install ffmpeg` (expects `/opt/homebrew/bin/ffmpeg` or `ffmpeg` on PATH)

### Linux
- Desktop toolchain:
  ```bash
  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
  ```
- FFmpeg for export:
  ```bash
  sudo apt install ffmpeg
  ```

### Web
- Chrome (or another Chromium browser) for screen recording

---

## Getting Started

```bash
flutter pub get
```

### macOS
```bash
flutter run -d macos
```

### Linux
```bash
flutter run -d linux
```

### Web
```bash
flutter run -d chrome
# or serve a release build:
flutter build web
# then host build/web/
```

---

## Architecture

- **UI / editor**: Dart (`lib/screens/`)
- **Capture facade**: `lib/services/capture_service*.dart` (Pigeon on macOS, MediaRecorder on web, import on Linux)
- **Export**: `lib/services/ffmpeg_runner*.dart` (desktop Process); web downloads the source clip
- **macOS native host**: Swift in `macos/Runner` (ScreenCaptureKit + window channel)

---

## Releases (CI/CD)

`.github/workflows/release.yml` builds the macOS app on a GitHub-hosted runner
and packages it as a `.dmg`.

**On every push** to `main`, `release`, or `feat/ci-cd` (and on PRs to `main` /
`release`, or via *Actions → Build macOS DMG → Run workflow*):

1. `verify` — `flutter analyze` + `flutter test` on Ubuntu. Formatting is
   reported but not enforced; analyzer *infos* are advisory, warnings and
   errors fail the build.
2. `build-macos` — `flutter build macos --release`, then `hdiutil` packs the
   `.app` plus an `/Applications` symlink into
   `Xowcase-<version>-macos.dmg`, uploaded as the `xowcase-macos-dmg`
   run artifact (90-day retention).

Non-tag builds are versioned `<pubspec version>-<short sha>`.

**To publish a GitHub Release**, push a `v*` tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `release` job then attaches the DMG and a `SHA256SUMS.txt` to a release
named after the tag, with auto-generated changelog notes appended.

The Flutter SDK version comes from `.fvmrc`, so keep that file committed and in
sync with what you develop against.

Local equivalent of the packaging step:

```bash
make dmg   # build/Xowcase.dmg
```

> Builds are **unsigned and un-notarized**. First launch needs
> *System Settings → Privacy & Security → Open Anyway*, and export still
> requires `ffmpeg` on the user's machine.

---

## Contributing

1. Format Dart before committing
2. After changing `pigeons/messages.dart`, regenerate Pigeon outputs
3. Test exports on desktop so FFmpeg filter graphs stay valid

---

**Made with ❤️ by IldySilva**
