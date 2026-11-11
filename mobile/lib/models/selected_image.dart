import 'dart:typed_data';

class SelectedImage {
  SelectedImage._({
    required this.name,
    required this.bytes,
    required this.extension,
  });

  static const maxBytes = 5 * 1024 * 1024;
  final String name;
  final Uint8List bytes;
  final String extension;

  String get uploadName => 'image.$extension';

  factory SelectedImage.fromBytes({
    required String name,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('This image is empty. Choose another image.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Choose an image smaller than 5 MB.');
    }
    String? extension;
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) {
      extension = 'png';
    } else if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      extension = 'jpg';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      extension = 'webp';
    }
    if (extension == null) {
      throw const FormatException('Choose a JPG, PNG, or WebP image.');
    }
    return SelectedImage._(name: name, bytes: bytes, extension: extension);
  }
}
