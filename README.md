# 🎞️ VideoSwiper

**VideoSwiper** is a Flutter desktop application that helps you preview and review video files using automatically generated thumbnail collages. Ideal for quickly scanning through large video folders and deciding which files to keep or delete.
![Video](video.gif)

---

## 📦 Download

You can download the latest Windows build here:

👉 **[Download VideoSwiper.exe](https://github.com/andrymas/VideoSwiper/releases/download/v1.0.0/VideoSwiper1.0.0.zip)**

- No installation required.
- Just download and run the `.exe` file.
- Requires Python 3 with `opencv-python` and `Pillow` installed and in PATH.

---

## ✨ Features

- 📁 **Batch Folder Selection**: Pick an entire folder of videos.
- ⚙️ **Wide Extension Compatibility**: This software recognizes lots of video extensions (`'.mp4'`, `'.avi'`, `'.mov'`, `'.mkv'`, `'.m4v'`, `'.webm'`, `'.flv'`, `'.wmv'`, `'.3gp'`, `'.3g2'`, `'.mpeg'`, `'.mpg'`, `'.ts'`)
- 🖼️ **Thumbnail Collage Generation**: Extracts evenly spaced frames and arranges them into a grid using Python + OpenCV + Pillow.
- ⚡ **Parallel Processing**: Up to N concurrent Python threads, with real-time progress and memory usage. 
- 🧹 **Easy Review UI**: Swipe through videos and choose to **keep** or **delete** each file.
- 🗑️ **Trash Folder**: Don't want to lose your files forever? This software doesn't delete, it just creates a trash folder to keep everything organized.
- 🎛️ **Configurable Parameters**: Adjust number of frames per collage and number of parallel jobs.

---

## 🧰 Code Requirements

- Dart 3.7 or newer
- Flutter 3.29 or newer
- Python 3.x
- OpenCV and Pillow libraries:
  `pip install opencv-python pillow`
