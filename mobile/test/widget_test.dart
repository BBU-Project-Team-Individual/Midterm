import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:midterm/main.dart';
import 'package:midterm/services/product_api.dart';

import 'fixtures.dart';

void main() {
  Future<void> launch(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final api = ProductApi(
      client: MockClient(handler),
      baseUrl: 'http://api.test/api/v1',
    );
    addTearDown(api.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lists products, changes category filter, and requests next page',
    (tester) async {
      final queries = <Map<String, String>>[];
      await launch(tester, (request) async {
        if (request.url.path.endsWith('categories')) {
          return categoriesResponse();
        }
        queries.add(request.url.queryParameters);
        final page = int.parse(request.url.queryParameters['page']!);
        return jsonResponse(
          collectionJson(
            [
              productJson(
                name: page == 1 ? 'Mineral Water' : 'Sparkling Water',
              ),
            ],
            page: page,
            lastPage: 2,
            total: 16,
          ),
        );
      });
      expect(find.text('Mineral Water'), findsOneWidget);
      expect(find.text('20 in stock'), findsOneWidget);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Sparkling Water'), findsOneWidget);
      expect(queries.last['page'], '2');
      await tester.tap(find.byKey(const ValueKey('category-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      expect(queries.last['CategoryID'], '4');
      expect(queries.last['page'], '1');
      await tester.tap(find.text('Clear Filter'));
      await tester.pumpAndSettle();
      expect(queries.last.containsKey('CategoryID'), isFalse);
      expect(queries.last['page'], '1');
      expect(find.text('All categories'), findsOneWidget);
    },
  );

  testWidgets(
    'create form validates, selects category, saves and refreshes list',
    (tester) async {
      Map<String, dynamic>? saved;
      await launch(tester, (request) async {
        if (request.url.path.endsWith('categories')) {
          return categoriesResponse();
        }
        if (request.method == 'POST') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({
            'data': productJson(name: saved!['ProductName'] as String),
          }, 201);
        }
        return jsonResponse(
          collectionJson(
            saved == null
                ? []
                : [productJson(name: saved!['ProductName'] as String)],
          ),
        );
      });
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Create product'));
      await tester.tap(find.text('Create product'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Enter a product name.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('ProductName')),
        'New water',
      );
      await tester.tap(find.byKey(const ValueKey('category-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beverages').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Create product'));
      await tester.tap(find.text('Create product'));
      await tester.pumpAndSettle();
      expect(saved!['CategoryID'], 3);
      expect(saved!['Qty'], 0);
      expect(saved!['Description'], isNull);
      expect(saved!.containsKey('ProductID'), isFalse);
      expect(find.text('New water'), findsOneWidget);
    },
  );

  testWidgets(
    'edit preserves fields, shows 422 barcode error, and retries successfully',
    (tester) async {
      var attempts = 0;
      Map<String, dynamic>? saved;
      await launch(tester, (request) async {
        if (request.url.path.endsWith('categories')) {
          return categoriesResponse();
        }
        if (request.method == 'PUT') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          attempts++;
          if (attempts == 1) {
            return jsonResponse({
              'message': 'Check your barcode.',
              'errors': {
                'Barcode': ['This barcode is already in use.'],
              },
            }, 422);
          }
          return jsonResponse({'data': productJson(name: 'Updated water')});
        }
        return jsonResponse(
          collectionJson([
            productJson(name: attempts > 1 ? 'Updated water' : 'Mineral Water'),
          ]),
        );
      });
      await tester.tap(find.byTooltip('Edit Mineral Water'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('ProductName')))
            .controller!
            .text,
        'Mineral Water',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ProductName')),
        'Updated water',
      );
      await reveal(tester, find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(saved!['Expiredate'], '2027-12-31');
      expect(saved!['UnitPriceIn'], '0.25');
      expect(saved!['ProductImage'], '/images/water.png');
      expect(find.text('Check your barcode.'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('Barcode')));
      expect(find.text('This barcode is already in use.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('Barcode')), '999999');
      await reveal(tester, find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(saved!['Barcode'], '999999');
      expect(find.text('Updated water'), findsOneWidget);
    },
  );

  testWidgets(
    'delete cancel sends nothing; confirmation handles 204 and refreshes',
    (tester) async {
      var deletes = 0;
      await launch(tester, (request) async {
        if (request.url.path.endsWith('categories')) {
          return categoriesResponse();
        }
        if (request.method == 'DELETE') {
          deletes++;
          return http.Response('', 204);
        }
        return jsonResponse(
          collectionJson(deletes == 0 ? [productJson()] : []),
        );
      });
      await tester.tap(find.byTooltip('Delete Mineral Water'));
      await tester.pumpAndSettle();
      expect(find.text('Delete product?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.byTooltip('Delete Mineral Water'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Mineral Water'), findsNothing);
      expect(find.text('No products yet'), findsOneWidget);
    },
  );

  testWidgets('failed list load offers retry and recovers', (tester) async {
    var fail = true;
    await launch(tester, (request) async {
      if (request.url.path.endsWith('categories')) return categoriesResponse();
      if (fail) {
        return jsonResponse({'message': 'Temporarily unavailable'}, 503);
      }
      return jsonResponse(collectionJson([productJson()]));
    });
    expect(find.text('Temporarily unavailable'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Mineral Water'), findsOneWidget);
  });
}
