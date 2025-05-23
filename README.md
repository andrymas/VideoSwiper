# 🎞️ VideoSwiper

**VideoSwiper** is a Flutter desktop application that helps you preview and review video files using automatically generated thumbnail collages. Ideal for quickly scanning through large video folders and deciding which files to keep or delete.
![Video](assets/video.gif)

---

## 📦 Download

You can download the latest Windows build here:

👉 **[Download VideoSwiper.exe](https://github.com/andrymas/videoswiper/releases/latest/download/VideoSwiper.exe)**

- No installation required.
- Just download and run the `.exe` file.
- Requires Python 3 with `opencv-python` and `Pillow` installed.

---

## ✨ Features

- 📁 **Batch Folder Selection**: Pick an entire folder of videos (`.mp4`, `.avi`, `.mov`, `.mkv`).
- 🖼️ **Thumbnail Collage Generation**: Extracts evenly spaced frames and arranges them into a grid using Python + OpenCV + Pillow.
- ⚡ **Parallel Processing**: Up to N concurrent Python workers with real-time progress and memory usage display.
- 🧹 **Easy Review UI**: Swipe through videos and choose to **keep** or **delete** each file.
- 🎛️ **Configurable Parameters**: Adjust number of frames per collage, number of parallel jobs, and grid layout.
- 💻 **Cross-Platform**: Flutter Desktop support for Windows (build), macOS, and Linux (source).

---

## 🧰 Requirements

### Flutter

- Flutter 3.7 or newer
- Python 3.x
- OpenCV and Pillow libraries:
  `pip install opencv-python pillow`
