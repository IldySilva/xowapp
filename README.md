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

## Contributing

1. Format Dart before committing
2. After changing `pigeons/messages.dart`, regenerate Pigeon outputs
3. Test exports on desktop so FFmpeg filter graphs stay valid

---

**Made with ❤️ by IldySilva**
