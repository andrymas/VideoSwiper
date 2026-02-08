# 🎞️ VideoSwiper

**VideoSwiper** is a Flutter desktop application that helps you preview and review video and image files using automatically generated thumbnail collages.
Ideal for quickly scanning through large media folders and deciding which files to keep or delete.

![Video](video.gif)

---

## 📦 Download

You can download the latest Windows build here:

👉 **[Download VideoSwiper.exe](https://github.com/andrymas/VideoSwiper/releases/download/v2.0.0/VideoSwiper2.0.0.zip)**

- No installation required  
- Just download and run the `.exe` file  
- Requires `FFMPEG FULL SHARED` installed and in your PATH

---

## ✨ Features

### 📁 Video Handling
- **Batch Folder Selection**: Pick an entire folder of files.
- **Wide Extension Compatibility**: Supports `.mp4`, `.avi`, `.mov`, `.mkv`, `.m4v`, `.webm`, `.flv`, `.wmv`, `.3gp`, `.3g2`, `.mpeg`, `.mpg`, `.ts`., `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.wbmp`
- **MediaGatherer**: Automatically gather files from nested directories into a single folder (with copy or move mode).

### 🖼️ Thumbnail Collage
- **Collage Generation**: Extracts evenly spaced frames and arranges them into a grid using a custom Rust algorithm.
- **Configurable Collage Quality**: Adjust output resolution and frame count.
- **Zoom & Drag**: Zoom into collages and scroll by dragging with your mouse.

### ⚡ Performance & Control
- **Parallel Processing**: Use multiple threads with real-time progress feedback.
- **Progress Indicator**: Displays a counter while generating thumbnails.

### 🎛️ UI & Usability
- **Bottom Action Bar**: Reorganized UI for easier navigation and quicker access.
- **Trash Folder System**: Files are not deleted directly—rejected videos go into a dedicated trash folder.
- **Slider Improvements**: Refined sliders for async job count and frame selection.

### 🔮 Future plans
- **Video compression**
- **Create a better icon for the project**
- **Batch selection with grid**
-**Custom settings for each video**

---

## 🧰 Requirements

- Dart 3.7 or newer  
- Flutter 3.29 or newer  
- FFMPEG FULL SHARED


---
## 🔧 Building From Source

  ```bash
  flutter clean
  flutter pub get
  flutter build windows
  ```

---
## Go check out my other project!
**[My website](https://www.andrymasdev.it)**

**[LoopBack](https://play.google.com/store/apps/details?id=com.andrymasdev.loopback.loopback)**
