import 'product_image.dart';

/// Non-web platforms: product photos are managed from the web build.
Future<PickedImage?> pickProductImage() async {
  throw UnsupportedError(
    'Product image picking is only available in the web build of MediGram.',
  );
}
