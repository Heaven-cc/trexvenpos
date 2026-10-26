import 'package:flutter/material.dart';
import '../lib/src/features/inventory/angel_auto_camera_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/src/features/inventory/angel_scan_client.dart';
import '../lib/src/features/inventory/product_review_screen.dart';

class FakeScan extends AngelScanClient {
  int submissions = 0, decisions = 0;
  Map<String, dynamic>? payload;
  FakeScan({bool inventory = true})
    : super(
        SupabaseClient(
          'https://example.test',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        businessId: 'business',
        inventoryMode: inventory,
      );
  @override
  void checkSession() {}
  @override
  Future<Map<String, dynamic>> researchProduct(
    Map<String, dynamic> item,
  ) async => {
    'summary': 'Manufacturer evidence remains advisory.',
    'sources': [
      {
        'url_citation': {
          'title': 'Manufacturer source',
          'url': 'https://example.test/product',
        },
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> submit({
    required String requestId,
    required String documentHash,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> metadata,
  }) async {
    submissions++;
    payload = {'items': items, 'metadata': metadata};
    return {
      'id': requestId,
      'status': 'pending',
      'application_status': 'not_applied',
    };
  }

  @override
  Future<Map<String, dynamic>> decide(String requestId, bool approve) async {
    decisions++;
    return {
      'id': requestId,
      'status': 'approved',
      'application_status': 'applied',
    };
  }
}

Map<String, dynamic> batch({bool matched = false}) => {
  'items': [
    {
      'name': 'Brake pad',
      'sku': '00123',
      'quantity': 2,
      'unit': 'piece',
      'selling_price': 99,
      'uncertain': true,
      'matches': matched
          ? [
              {
                'name': 'Brake pad',
                'sku': '00123',
                'product_id': 'product',
                'unit': 'piece',
                'quantity': 20,
                'selling_price': 40,
                'active': true,
                'score': 95,
              },
            ]
          : [],
    },
  ],
  'type': 'document',
  'document_hash': 'a' * 64,
  'supplier': 'Supplier A',
  'document_number': 'INV-1',
  'source_label': 'Receipt scanned by Angel',
};
Future<void> open(
  WidgetTester tester,
  FakeScan api,
  bool single, {
  Future<bool> Function(Map<String, dynamic>)? onSale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAngelProductReview(
              context,
              api: api,
              result: batch(matched: true),
              singleProduct: single,
              onSale: onSale,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'camera glass controls stay 44px on a narrow screen and lists are inventory-only',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final inventory in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: AngelAutoCameraScreen(
              key: ValueKey(inventory),
              api: FakeScan(inventory: inventory),
              onRecognized: (_, __) async {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Angel Scan'), findsOneWidget);
        for (final label in ['Flash', 'Flip', 'Gallery', 'File']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(
          find.text('Receipt / List'),
          inventory ? findsOneWidget : findsNothing,
        );
        for (final element in find.byType(BackdropFilter).evaluate()) {
          expect((element.renderObject as RenderBox).size.height, 44);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'single product stays in a bottom sheet and selling selects existing inventory',
    (tester) async {
      final api = FakeScan(inventory: false);
      var sales = 0;
      await open(
        tester,
        api,
        true,
        onSale: (match) async {
          expect(match['product_id'], 'product');
          sales++;
          return true;
        },
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Review products'), findsNothing);
      await tester.tap(find.text('Research product online'));
      await tester.pumpAndSettle();
      expect(find.text('Manufacturer source'), findsOneWidget);
      expect(find.text('Public research · advisory only'), findsOneWidget);
      await tester.tap(find.text('Select product and add to checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm product'));
      await tester.pumpAndSettle();
      expect(sales, 1);
      expect(api.submissions, 0);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'one-line receipt uses review page and manager submission never decides or posts',
    (tester) async {
      final api = FakeScan();
      await open(tester, api, false);
      expect(find.text('Review products'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Receipt scanned by Angel'), findsOneWidget);
      await tester.tap(find.text('Request owner approval'));
      await tester.pumpAndSettle();
      expect(api.submissions, 0);
      expect(
        find.text('Confirm every product before continuing.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Brake pad').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request owner approval'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(api.submissions, 1);
      expect(api.decisions, 0);
      final item = (api.payload!['items'] as List).single as Map;
      expect(item['product_id'], 'product');
      expect(item.containsKey('selling_price'), false);
      expect((api.payload!['metadata'] as Map)['documents'], [
        {'supplier': 'Supplier A', 'document_number': 'INV-1'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'catalog retries freeze payload and retain request id after interrupted confirmation',
    (tester) async {
      final api = FakeScan();
      final requests = <String>[];
      final payloads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ProductReviewScreen(
            api: api,
            owner: true,
            sourceLabel: 'Manual CSV import',
            initialItems: const [
              {'name': 'Bolt', 'initial_quantity': 4},
            ],
            validateCatalog: (rows) async => rows,
            confirmCatalog: (rows, request) async {
              requests.add(request);
              payloads.add(rows.toString());
              throw StateError('Connection interrupted');
            },
          ),
        ),
      );
      await tester.tap(find.text('Confirm import'));
      await tester.pumpAndSettle();
      expect(find.text('Retry same request'), findsOneWidget);
      await tester.tap(find.text('Retry same request'));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(payloads[0], payloads[1]);
      expect(tester.takeException(), isNull);
    },
  );
}
