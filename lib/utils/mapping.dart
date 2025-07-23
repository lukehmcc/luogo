import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:image/image.dart' as img;

/// Adds an image from an asset to the current map style with a colored circle and letter overlay.
///
/// This function:
/// - Loads an image from the specified asset
/// - Draws a colored circle at a fixed position on the image
/// - Adds a letter overlay in the center
/// - Adds the final composited image to the map style
///
/// Parameters:
/// - `controller`: The [MapLibreMapController] instance used to add the image to the map
/// - `name`: The unique identifier for this image in the map style
/// - `assetName`: The path to the asset image (e.g., 'assets/images/marker.png')
/// - `color`: The [Color] of the circle to be drawn
/// - `letter`: The single character to be drawn on top of the circle
///
/// Returns:
/// A [Future] that completes when the image has been added to the map style
Future<void> addImageFromAsset(MapLibreMapController controller, String name,
    String assetName, Color color, String letter) async {
  final Uint8List bytes =
      await addColoredCircleAndLetterToImage(assetName, color, letter);
  final Uint8List list = bytes.buffer.asUint8List();
  return controller.addImage(name, list);
}

/// Creates a composite image by adding a colored circle and letter to an asset image.
///
/// This helper function:
/// 1. Loads and decodes the original image from assets
/// 2. Draws a colored circle at fixed coordinates
/// 3. Creates a separate image with the provided letter
/// 4. Composites both images together
/// 5. Encodes the result as PNG
///
/// Parameters:
/// - `assetName`: The path to the asset image (e.g., 'assets/images/marker.png')
/// - `color`: The [Color] of the circle to be drawn
/// - `letter`: The single character to be drawn on top of the circle
///
/// Returns:
/// A [Future<Uint8List>] containing the PNG-encoded bytes of the composited image
Future<Uint8List> addColoredCircleAndLetterToImage(
    String assetName, Color color, String letter) async {
  // 1. Load and decode the original image
  final bytes = await rootBundle.load(assetName);
  final image = img.decodeImage(bytes.buffer.asUint8List())!;

  // 2. Draw a colored circle (x, y, radius, color)
  final circleColor = img.ColorRgb8(
      (color.r * 255).toInt(),
      (color.g * 255).toInt(),
      (color.b * 255).toInt()); // Blue (R=0, G=0, B=255)
  img.fillCircle(
    image,
    x: 100, // Center X
    y: 84, // Center Y
    radius: 67,
    color: circleColor,
  );
  final letterImage = img.Image(width: 100, height: 100, numChannels: 4);
  img.fill(letterImage, color: img.ColorRgba8(0, 0, 0, 0));

  img.drawString(
    letterImage,
    letter[0].toUpperCase(),
    font: img.arial48,
    y: 22,
    color: img.ColorRgb8(0, 0, 0),
  );

// Now scale it up
  final img.Image scaledLetter =
      img.copyResize(letterImage, width: 200, height: 200);

// Paste onto your main image
  img.compositeImage(image, scaledLetter);
  // 3. Encode back to PNG (or JPEG/WebP)
  return img.encodePng(image);
}
