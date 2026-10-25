import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import 'product_provider.dart';
import 'product_repository.dart';
import 'angel_scan_client.dart';
import 'angel_scan_review_screen.dart';
import 'angel_auto_camera_screen.dart';

/// Existing checkout callback contract. Stock remains unchanged until checkout.
typedef ScannedProductHandler = Future<bool> Function(
    Product product, String scanEventId);

/// Opens only a clear camera surface; light and camera flip are the sole controls.
/// Angel analyzes throttled stable snapshots and opens an existing review screen.
class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key, this.onProductMatched, this.barcodeResult = false});
  final bool barcodeResult;
  final ScannedProductHandler? onProductMatched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final business = auth.activeBusiness;
    final employee = auth.employee;
    final permission = ref.watch(permissionServiceProvider);
    if (business == null || employee == null || auth.offlineCashOnly ||
        !permission.canCompleteSales) {
      return const Scaffold(body: Center(child: Text('Connect and verify selling access.')));
    }
    final branch = business.branchesEnabled
        ? ref.watch(branchContextProvider)?.id : null;
    if (business.branchesEnabled && branch == null) {
      return const Scaffold(body: Center(child: Text('Select an authorized branch.')));
    }
    final api = AngelScanClient(ref.watch(supabaseProvider),
      businessId: business.id, branchId: branch, inventoryMode: false);
    bool current() {
      final now = ref.read(authStateProvider);
      return context.mounted && !now.offlineCashOnly &&
        now.activeBusiness?.id == business.id &&
        now.employee?.membershipId == employee.membershipId &&
        ref.read(permissionServiceProvider).canCompleteSales &&
        (!business.branchesEnabled || ref.read(branchContextProvider)?.id == branch);
    }

    return AngelAutoCameraScreen(
      api: api,
      contextIsCurrent: current,
      onRecognized: (items, sourceHash) async {
        if (!current()) return;
        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
          AngelScanReviewScreen(
            api: api,
            initialItems: items,
            automaticSourceHash: sourceHash,
            contextIsCurrent: current,
            onSale: (match) async {
              if (!current()) return false;
              final db = ref.read(supabaseProvider);
              final row = await db.from('products')
                  .select(ProductRepository.catalogProductColumns)
                  .eq('id', match['product_id'])
                  .eq('business_id', business.id).single();
              if (!current()) return false;
              final branchProducts = await ref.read(productRepositoryProvider)
                  .branchStock([Product.fromJson(row)], business.id, branch);
              if (branchProducts.isEmpty) return false;
              final product = branchProducts.single;
              if (!product.isActive || product.sellingPrice == null) return false;
              if (onProductMatched == null) {
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context, barcodeResult ? product.barcode : product);
                }
                return true;
              }
              return onProductMatched!(product, const Uuid().v4());
            },
          ),
        ));
      },
    );
  }
}
