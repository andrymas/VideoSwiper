import 'dart:io';

class MediaClass {
  File fileReference;
  bool isVideo;

  MediaClass({required this.fileReference, required this.isVideo});
  
  get path => fileReference!.path;
}

enum QualityLevel {
  lowest,
  low,
  medium,
  high,
  ultra,
}

extension QualityLevelExtension on QualityLevel {
  String toDisplayString() {
    return toString().split('.').last[0].toUpperCase() +
      toString().split('.').last.substring(1);
  }
}