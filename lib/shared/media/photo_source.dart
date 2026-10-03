import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A photo the user took or picked, kept in memory so a failed upload can be
/// retried without asking for it again.
class PickedPhoto {
  final String name;
  final Uint8List bytes;
  const PickedPhoto(this.name, this.bytes);
}

/// Lets a screen ask for a photo and be tested without a camera.
typedef PhotoPicker = Future<PickedPhoto?> Function(BuildContext context);

abstract final class PhotoSource {
  /// Camera or gallery. Resized and compressed so a phone photo stays far
  /// below the server's 10 MB limit.
  static Future<PickedPhoto?> choose(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2200,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PickedPhoto(file.name, await file.readAsBytes());
  }
}
