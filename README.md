# 🎞️ VideoSwiper

**VideoSwiper** is a Flutter desktop application that helps you preview and review video and image files using automatically generated thumbnail collages.
Ideal for quickly scanning through large media folders and deciding which files to keep or delete.

![Video](video.gif)

---

## 📦 Download

You can download the latest Windows build here:

👉 **[Download VideoSwiper.exe](https://github.com/andrymas/VideoSwiper/releases/download/v1.2.0/VideoSwiper1.2.0.zip)**

- No installation required  
- Just download and run the `.exe` file  
- Requires Python 3 with `opencv-python` and `Pillow` installed and available in your system PATH  

---

## ✨ Features

### 📁 Video Handling
- **Batch Folder Selection**: Pick an entire folder of files.
- **Wide Extension Compatibility**: Supports `.mp4`, `.avi`, `.mov`, `.mkv`, `.m4v`, `.webm`, `.flv`, `.wmv`, `.3gp`, `.3g2`, `.mpeg`, `.mpg`, `.ts`., `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.wbmp`
- **MediaGatherer (Beta)**: Automatically gather files from nested directories into a single folder (with copy or move mode).

### 🖼️ Thumbnail Collage
- **Collage Generation**: Extracts evenly spaced frames and arranges them into a grid using Python, OpenCV, and Pillow.
- **Configurable Collage Quality**: Adjust output resolution and frame count.
- **Zoom & Drag**: Zoom into collages and scroll by dragging with your mouse.

### ⚡ Performance & Control
- **Parallel Processing**: Run multiple Python workers with real-time progress feedback.
- **Progress Indicator**: Displays a counter while generating thumbnails.
- **Dynamic Aspect Ratio**: Video player adapts automatically to video dimensions.

### 🎛️ UI & Usability
- **Bottom Action Bar**: Reorganized UI for easier navigation and quicker access.
- **Portrait Video Support**: Improved layout for vertical videos.
- **Autoplay & Auto-Mute Settings**: Customize playback behavior (start paused, muted, or autoplay).
- **Trash Folder System**: Files are not deleted directly—rejected videos go into a dedicated trash folder.
- **Slider Improvements**: Refined sliders for async job count and frame selection.

### 🔮 Future plans
- **Video compression**
- **Android port**
- **Create a better icon for the project**
- **Batch selection with grid**

---

## 🧰 Requirements

- Dart 3.7 or newer  
- Flutter 3.29 or newer  
- Python 3.x  
- Python dependencies:
  ```bash
  pip install opencv-python pillow


---
## 🔧 Building From Source

  ```bash
  flutter clean
  flutter pub get
  flutter build windows
  ```

---
## Go check out my other project!
**[My website](www.andrymasdev.it)**
**[LoopBack](https://play.google.com/store/apps/details?id=com.andrymasdev.loopback.loopback)**
