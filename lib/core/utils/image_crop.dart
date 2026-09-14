import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

// Standard phone screen ratio (e.g. 1080x1920) — banners are shown full-bleed
// as a portrait discovery card and a full-screen profile-header background,
// both of which are basically a phone screen, so this is the shape that
// actually avoids letterboxing/cropping surprises at display time.
const _bannerAspectRatio = CropAspectRatio(ratioX: 9, ratioY: 16);

/// Launches the native crop UI for a freshly picked image, locked to the
/// standard phone-screen aspect ratio. Returns null if the user backs out.
Future<XFile?> cropImage(
  String sourcePath, {
  String title = 'Crop photo',
}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: _bannerAspectRatio,
    uiSettings: [
      AndroidUiSettings(toolbarTitle: title, lockAspectRatio: true),
      IOSUiSettings(
        title: title,
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
    ],
  );
  if (cropped == null) return null;
  return XFile(cropped.path);
}
