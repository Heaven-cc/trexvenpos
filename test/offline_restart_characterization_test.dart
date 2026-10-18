import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trexvenpos/src/features/auth/branch_context.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/models/product.dart';

// Two separate Flutter test processes characterize the current persistence gap.
// The evidence file is written by this test only; the application never reads it.
// Passing this test does NOT mean durable offline recovery is implemented.
void main() {
  const phase = String.fromEnvironment(
    'RESTART_PHASE',
    defaultValue: 'inspect',
  );
  test(
    'fresh process exposes existing cart/request/branch persistence boundary',
    () {
      final cart = CartNotifier();
      final branch = BranchContext('synthetic-business');
      final evidence = File('.batch2-tools/offline_restart_before.json');
      if (phase == 'before') {
        cart.addProduct(
          const Product(
            id: 'synthetic-product',
            name: 'Synthetic',
            businessId: 'synthetic-business',
          ),
          10,
          'standard',
        );
        const selected = AuthorizedBranch(
          id: 'synthetic-branch',
          businessId: 'synthetic-business',
          name: 'Synthetic',
        );
        branch.select(selected, [selected], hasCart: false);
        evidence.parent.createSync(recursive: true);
        evidence.writeAsStringSync(
          jsonEncode({
            'pid': pid,
            'request_id': cart.checkoutRequestId,
            'cart_count': cart.state.length,
            'branch_id': branch.state?.id,
          }),
        );
        expect(cart.state, hasLength(1));
        expect(branch.state?.id, selected.id);
      } else if (phase == 'after') {
        final previous =
            jsonDecode(evidence.readAsStringSync()) as Map<String, dynamic>;
        expect(pid, isNot(previous['pid']));
        expect(cart.state, isEmpty);
        expect(cart.checkoutRequestId, isNot(previous['request_id']));
        expect(branch.state, isNull);
      } else {
        expect(cart.state, isEmpty);
        expect(branch.state, isNull);
      }
      cart.dispose();
      branch.dispose();
    },
  );
}
