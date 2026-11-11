import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

Uint8List testImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
);

class FakeImageSelector extends FileSelectorPlatform {
  FakeImageSelector({this.file, this.error});
  XFile? file;
  final Object? error;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    if (error != null) throw error!;
    return file;
  }
}

void useTestImagePicker(void Function(void Function()) addTearDown) {
  final original = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = FakeImageSelector(
    file: XFile.fromData(
      testImageBytes(),
      name: 'photo.png',
      path: 'photo.png',
    ),
  );
  addTearDown(() => FileSelectorPlatform.instance = original);
}
