import 'package:file_selector/file_selector.dart';

import '../models/selected_image.dart';

Future<SelectedImage?> chooseDeviceImage() async {
  const images = XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    uniformTypeIdentifiers: [
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );
  final file = await openFile(
    acceptedTypeGroups: [images],
    confirmButtonText: 'Choose image',
  );
  if (file == null) return null;
  if (await file.length() > SelectedImage.maxBytes) {
    throw const FormatException('Choose an image smaller than 5 MB.');
  }
  return SelectedImage.fromBytes(
    name: file.name,
    bytes: await file.readAsBytes(),
  );
}
