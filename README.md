# XowCase

**XowCase** is a powerful macOS desktop application built to create stunning, professional app demos and showcases. 

Built with a hybrid architecture—using **Flutter** for a fluid, responsive UI and **Swift/Native APIs** for high-performance screen capturing—XowCase allows you to record your screen, simulator, or physical devices, wrap them in beautiful device frames, and export them into high-quality videos using FFmpeg.

---

## 🚀 Features

- **Native Screen & Simulator Capture**: Connects directly to macOS APIs (via Swift) to capture simulators, windows, or full screens flawlessly.
- **Beautiful Device Frames**: Wrap your recordings in realistic device frames (e.g., iPhones, Androids).
- **Advanced Cropping**: Visually crop your video inside the device frame without breaking the final resolution (Top Half, Bottom Half, Custom Rectangular crop).
- **Dynamic Backgrounds**: Add solid colors or transparent backgrounds to your showcase.
- **Custom Export Resolutions**: Export directly to popular aspect ratios:
  - 16:9 (YouTube, Twitter/X)
  - 1:1 (Square, Instagram)
  - 3:4 (Portrait)
- **High-Performance Export**: Uses `ffmpeg` with `h264_videotoolbox` for hardware-accelerated Apple Silicon rendering.

---

## 🛠 Prerequisites

To build and run XowCase locally, you need the following tools installed on your Mac:

1. **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install/macos) (Make sure you are on the `stable` channel).
2. **Xcode**: Required for compiling the macOS desktop app and the Swift native code. Install it from the Mac App Store.
3. **FFmpeg**: Required for the video export pipeline. It must be installed via Homebrew:
   ```bash
   brew install ffmpeg
   ```
   *(Note: XowCase currently expects the FFmpeg binary to be located at `/opt/homebrew/bin/ffmpeg`)*

---

##  Getting Started

Follow these steps to set up the project on your local machine:

1. **Clone the repository**
   ```bash
   git clone https://github.com/IldySilva/xowapp.git
   cd xowapp
   ```

2. **Clean and fetch dependencies**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Run the app**
   To run the app in debug mode on your Mac:
   ```bash
   flutter run -d macos
   ```

---

##  Architecture Overview

XowCase uses a hybrid architecture to get the best of both worlds:
- **Frontend (UI & Editor)**: Written in Dart/Flutter. Handles the timeline, the visual canvas layout, crop settings, and video playback.
- **Backend (Capture & System)**: Written in Swift (inside `macos/Runner`). Uses Pigeon (`messages.g.dart`) to communicate seamlessly with Flutter. Handles native screen recording using `ScreenCaptureKit` and `AVFoundation`.
- **Export Engine**: Orchestrates complex FFmpeg filter graphs (`-filter_complex`) to merge backgrounds, device frame masks, and the video recording into a perfectly cropped, high-bitrate `.mp4`.

---

##  Roadmap & Future Plans

We have an extensive backlog of features planned for XowCase, including:
- Dual capture (Screen + Webcam)
- Multitrack timeline and automatic captions
- Cinematic motion blur and custom animation curves
- GIF export and Lossless presets

*(Detailed future plans are kept locally in `future.plans.md`)*

---

##  Contributing

When contributing to XowCase:
1. Please ensure you format your Dart code before committing.
2. If you modify the Pigeon communication interface (`pigeons/messages.dart`), make sure to regenerate the pigeon files.
3. Test video exports locally to ensure FFmpeg mappings remain unbroken.

---

**Made with ❤️ by IldySilva**
