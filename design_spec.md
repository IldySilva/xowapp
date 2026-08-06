Here is a comprehensive UI/UX design specification and prompt guideline for building the Flutter frontend of the macOS app demo recorder, directly mapped to the visual language of the reference image (`cfbfc247a1e83d8ecf815ed9c3a4f90b.webp`).

### **Core Design Philosophy & Architecture**

The application must deliver a clean, modern, and minimalist aesthetic tailored for macOS desktop environments. The interface relies on a dark-mode-first approach, utilizing subtle elevation, rounded corners, and clearly delineated workspaces to manage complex video editing and recording tasks without overwhelming the user.

The architecture is strictly hybrid: Flutter handles all layout, orchestration, and UI state management detailed below, while communicating via `MethodChannel` and `EventChannel` with native Swift modules responsible for screen capture, Metal-based 3D scene rendering, and AVFoundation export.

---

### **Visual Language & Styling Guidelines**

Implement a centralized Flutter `ThemeData` to enforce strict visual consistency across the app.

| Element | Specification (Hex / Styling) | Application |
| --- | --- | --- |
| **App Background** | `#0D0D0D` (Deep Black) | The root scaffold background for the entire application. |
| **Panel Background** | `#1A1A1A` to `#222222` | Left sidebar, timeline container, and inspector panels. |
| **Primary Accent** | `#A8D0E6` (Soft Cyan/Blue) | Call-to-action buttons (Export), active states, selected radio/toggles, timeline playhead. |
| **Text (Primary)** | `#FFFFFF` (White) | Headings, active values, and core readable text. |
| **Text (Secondary)** | `#8E8E93` (Grey) | Helper text, inactive icons, timeline timestamps. |
| **Border Radius** | `16px` (Large) / `8px` (Small) | Large for main panels and canvas; small for buttons and track items. |

---

### **Layout & Structural Architecture**

The workspace is divided into five distinct, resizable, and modular panels:

**1. Global Sidebar (Far Left)**

* **Width:** Fixed (~70px).
* **Purpose:** App-level navigation.
* **UI Elements:** Top brand logo. Vertically stacked, centered `IconButton` widgets with text labels (Home, Projects, Templates, Starred). Bottom-aligned utility icons (Settings, Help, User Avatar).
* **Styling:** Transparent background, blending directly with the root scaffold.

**2. Top Navigation & Toolbar**

* **Height:** Fixed (~50px).
* **Left:** Custom macOS traffic lights (red, yellow, green) implemented via a frameless window configuration, followed by navigation arrows and a project title dropdown.
* **Center:** Editing tool icons (Select, Text, Shape/Device Frame, Bookmark).
* **Right:** Share icon and a prominent, pill-shaped "Export" `ElevatedButton` utilizing the Primary Accent color.

**3. Assets & Scene Panel (Left Workspace)**

* **Width:** Fixed or restricted flex (~300px).
* **Purpose:** Selection of input sources, device frames, and 3D scene environments.
* **UI Elements:**
* A rounded `TextField` for search.
* **Device/Scene List:** A `ListView` functioning as a radio-group for selecting the environment (e.g., "Minimalist 3D," "Glossy Desk," "Transparent"). Use a circular checkmark icon for the active state.
* **Filters/Overlays Grid:** A `GridView` displaying rounded thumbnail images for visual effects or device bezel colors.



**4. Preview Canvas (Center)**

* **Flex:** `Expanded` (takes up remaining space).
* **Purpose:** The main native view for real-time rendering.
* **UI Elements:** A large, rounded container housing a `PlatformView` (or Texture widget) displaying the Swift-rendered 3D scene, simulator, or screen capture. This area must maintain the aspect ratio selected in the right panel.

**5. Inspector Panel (Right Workspace)**

* **Width:** Fixed (~300px).
* **Purpose:** Configuration for the selected clip and global export settings.
* **UI Elements:**
* **Segmented Control:** Toggle between specific source settings (e.g., "Screen," "Camera").
* **Format Selection:** A grid of rounded rectangles for aspect ratios (`9:16`, `3:4`, `1:1`, `4:3`). The active state is indicated by a subtle background highlight and a checkmark icon.
* **Quality Selection:** Pill-shaped toggles for resolutions (`720p`, `1080p`, `4K`).



---

### **Timeline Interface (Bottom Panel)**

The timeline requires highly interactive, custom-painted Flutter widgets to handle video editing mechanics.

* **Header Bar:**
* Left-aligned tool icons (Undo, Redo, Cut/Split).
* Center-aligned playback controls (Step backward, Play/Pause in a prominent circular accent button, Step forward, Loop).
* Right-aligned timeline utilities (Delete, Zoom to fit, Options).


* **Ruler:** A horizontal time axis (`CustomPaint`) displaying second intervals (`0s`, `5s`, `10s`) with distinct tick marks.
* **Playhead:** A vertical line traversing all tracks, anchored by a diamond-shaped handle at the ruler level.
* **Tracks:**
* **Video/Screen Track:** Rounded rectangular blocks containing horizontal image sequences (thumbnails).
* **Audio Track:** Rounded blocks displaying procedural waveforms.
* **Modifier Tracks:** Thinner pill-shaped blocks for effects, text, or device frame transitions, styled with darker backgrounds and colored borders (e.g., "Text: Demo Intro", "Effect: Gaussian Blur").
* **Interactivity:** Tracks must support drag-and-drop, trimming via edge handles, and tap-to-select (highlighting the clip with a bright border).



### **Flutter Implementation Directives**

* **Window Management:** Use a package like `bitsdojo_window` or `window_manager` to strip the default macOS title bar and seamlessly integrate the red/yellow/green native window controls into your custom dark top bar.
* **State Management:** Due to the complex interplay between the timeline, canvas, and inspector, utilize a robust state management solution (like Riverpod or Bloc) to ensure scrubbers and preview states remain perfectly synchronized without rebuilding the entire UI tree.
* **Hover & Focus:** Since this is a desktop application, implement subtle `onHover` color transitions (lightening panel backgrounds by ~5%) on all clickable elements to reinforce a tactile, modern desktop feel.