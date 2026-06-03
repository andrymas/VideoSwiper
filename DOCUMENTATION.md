# VideoSwiper Documentation

Welcome to the internal documentation for **VideoSwiper**, a modern, desktop-first media management application built with Flutter and Rust.

## Architecture Overview

VideoSwiper utilizes a hybrid architecture:
- **Frontend (Flutter)**: Handles the UI, state management, layouts, and user interactions.
- **Backend (Rust)**: Executes the generation of video collage thumbnails asynchronously using multithreading.

The two environments communicate seamlessly via `flutter_rust_bridge`.

---

## State Management

The application relies on a clean and decoupled state management architecture using Flutter's native `ChangeNotifier` and `ListenableBuilder`.

### `MediaController` (`lib/core/media_controller.dart`)
This is the heart of the application logic. It handles:
- **Settings & Preferences**: Such as collage frame counts, quality, and threading limits.
- **Media File Management**: Scanning directories, filtering video/photo extensions, and maintaining the list of active/kept files.
- **Rust Integration**: Dispatches processing tasks to the Rust backend and monitors completion/RAM usage to provide real-time UI feedback.
- **File Operations**: Features like moving deleted files to a local trash bin (`trash` folder).

By completely decoupling this logic from the UI tree, the interface remains highly responsive and easy to refactor.

---

## UI Architecture

The UI uses a clean, collapsible sidebar and an expansive main content area.

### `DashboardScreen` (`lib/ui/screens/dashboard_screen.dart`)
The main entry point after initialization. It instantiates the global `MediaController` and wraps the layout in a `ListenableBuilder`. It listens to window close events to prevent accidental exits if collages are still being generated.

### `MainLayout` (`lib/ui/layouts/main_layout.dart`)
Responsible for the structural skeleton of the app. It holds:
- **Sidebar**: The left navigation panel.
- **Content Area**: The main display panel taking up the remaining screen space.

### `Sidebar` (`lib/ui/widgets/sidebar.dart`)
The navigational anchor of the application. It provides:
- View toggling (Library Grid vs. Swiper).
- Action triggers (Opening folders, Launching Media Gatherer).
- Application options (Version Info, Settings).

### `ContentArea` (`lib/ui/widgets/content_area.dart`)
Renders the grid of loaded media files (`VideoCard`). When a card is clicked, it manages the overlay transition into the `FullscreenPreview`.

### `FullscreenPreview` (`lib/ui/widgets/fullscreen_preview.dart`)
Provides an immersive preview mode. For videos, it first shows the high-quality collage, and upon secondary interaction, initializes the `media_kit` native player directly on top of the collage.

### `SwiperView` (`lib/ui/screens/swiper_view.dart`)
An alternate, focused visualization mode ("Tinder-like") for reviewing media files sequentially. It supports full keyboard navigation (arrow keys) and smooth slide animations.

---

## Backend Interoperability

The Rust backend is initialized early in the Flutter lifecycle via `RustLib.init()` inside `main.dart`. 
Heavy tasks like `generateCollage()` yield asynchronous streams back to Dart, allowing the `MediaController` to incrementally update progress bars and process counts without blocking the main UI thread.

## UI/UX Aesthetics

The app adopts a premium, minimalistic "dark mode" aesthetic:
- **Colors**: Based heavily on deep charcoal and off-blacks (`#0B0B0C`, `#121214`).
- **Typography**: Clean, sans-serif fonts.
