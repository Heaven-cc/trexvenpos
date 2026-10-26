import 'product_review_screen.dart';

/// Compatibility for existing owner notification/revision navigation.
class AngelScanReviewScreen extends ProductReviewScreen {
  const AngelScanReviewScreen({
    super.key,
    required super.api,
    super.owner = false,
    super.initialItems = const [],
    super.existingRequestId,
    super.automaticSourceHash,
    Future<String?> Function()? scanBarcode,
    super.onSale,
    super.contextIsCurrent,
  });
}
