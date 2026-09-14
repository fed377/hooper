import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// On-device check that a captured profile photo actually shows a face —
/// not full identity verification (it can't tell who the face belongs to),
/// but it stops the laziest catfishing case of uploading a random non-face
/// image, and pairs with forcing the shot to come from the live camera
/// rather than the gallery.
Future<bool> imageContainsFace(String imagePath) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );
  try {
    final faces = await detector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return faces.isNotEmpty;
  } finally {
    await detector.close();
  }
}
