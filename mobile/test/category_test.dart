import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:midterm/main.dart';
import 'package:midterm/services/product_api.dart';

import 'fixtures.dart';
import 'image_helpers.dart';

void main() {
  ProductApi apiFor(Future<http.Response> Function(http.Request) handler) {
    final api = ProductApi(
      client: MockClient(handler),
      baseUrl: 'http://api.test/api/v1',
    );
    addTearDown(api.close);
    return api;
  }

  for (final id in [null, 3]) {
    test(
      'category ${id == null ? 'create' : 'update'} uses Laravel field names',
      () async {
        final api = apiFor((request) async {
          expect(request.method, id == null ? 'POST' : 'PUT');
          expect(
            request.url.path,
            id == null ? '/api/v1/categories' : '/api/v1/categories/3',
          );
          expect(jsonDecode(request.body), {
            'category_name': 'Drinks',
            'description': null,
            'image': '/images/drinks.png',
          });
          return jsonResponse({
            'data': {
              'category_id': 3,
              'category_name': 'Drinks',
              'image': '/images/drinks.png',
              'description': null,
            },
          }, id == null ? 201 : 200);
        });
        final category = await api.saveCategory(
          id: id,
          name: 'Drinks',
          image: '/images/drinks.png',
        );
        expect(category.id, 3);
        expect(category.image, '/images/drinks.png');
      },
    );
  }

  test('category delete preserves conflict message', () async {
    final api = apiFor((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/v1/categories/3');
      return jsonResponse({
        'message': 'Cannot delete a category that has products, including deleted products.',
      }, 409);
    });
    await expectLater(
      api.deleteCategory(3),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 409)
            .having(
              (error) => error.message,
              'message',
              contains('including deleted products'),
            ),
      ),
    );
  });

  testWidgets(
    'creates a category in Categories and selects it in a product form',
    (tester) async {
      useTestImagePicker(addTearDown);
      Map<String, dynamic>? product;
      var categoryCreated = false;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('uploads')) {
          return jsonResponse({
            'data': {'path': '/storage/catalog/snacks.png'},
          }, 201);
        }
        if (request.url.path.endsWith('categories')) {
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {
              'category_name': 'Snacks',
              'description': null,
              'image': '/storage/catalog/snacks.png',
            });
            categoryCreated = true;
            return jsonResponse({
              'data': {
                'category_id': 8,
                'category_name': 'Snacks',
                'image': '/storage/catalog/snacks.png',
              },
            }, 201);
          }
          return jsonResponse(
            collectionJson(
              categoryCreated
                  ? [
                      {
                        'category_id': 8,
                        'category_name': 'Snacks',
                        'image': '/storage/catalog/snacks.png',
                      },
                    ]
                  : [],
            ),
          );
        }
        if (request.method == 'POST') {
          product = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({
            'data': {...productJson(name: 'Chips'), 'CategoryID': 8},
          }, 201);
        }
        return jsonResponse(collectionJson([]));
      });
      await tester.pumpWidget(MyApp(api: api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();
      expect(categoryCreated, isFalse);
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Choose an image.'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('category_name')),
        'Snacks',
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Choose image').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsOneWidget);
      await tester.tap(find.text('Products').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('New category'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('ProductName')),
        'Chips',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('category-picker')));
      await tester.tap(find.byKey(const ValueKey('category-picker')));
      await tester.pumpAndSettle();
      expect(find.text('All categories'), findsNothing);
      await tester.tap(find.text('Snacks').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create product'));
      await tester.pumpAndSettle();
      expect(product!['CategoryID'], 8);
      expect(product!['ProductName'], 'Chips');
    },
  );

  testWidgets('category edit keeps image; blocked deletion retains category', (
    tester,
  ) async {
    var name = 'Beverages';
    final api = apiFor((request) async {
      if (request.url.path.endsWith('products')) {
        return jsonResponse(collectionJson([]));
      }
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['image'], '/beverages.png');
        name = body['category_name'] as String;
        return jsonResponse({
          'data': {
            'category_id': 3,
            'category_name': name,
            'image': '/beverages.png',
          },
        });
      }
      if (request.method == 'DELETE') {
        return jsonResponse({
          'message': 'Cannot delete a category that has products.',
        }, 409);
      }
      return jsonResponse(
        collectionJson([
          {'category_id': 3, 'category_name': name, 'image': '/beverages.png'},
        ]),
      );
    });
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Beverages'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category_name')),
      'Drinks',
    );
    await tester.tap(find.text('Save category'));
    await tester.pumpAndSettle();
    expect(find.text('Drinks'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete Drinks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text('Cannot delete a category that has products.'),
      findsOneWidget,
    );
    expect(find.text('Drinks'), findsOneWidget);
  });

  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('product and category layouts fit ${size.width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = apiFor(
        (request) async => request.url.path.endsWith('categories')
            ? categoriesResponse()
            : jsonResponse(collectionJson([productJson()])),
      );
      await tester.pumpWidget(MyApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Categories').last);
      await tester.pumpAndSettle();
      expect(find.text('Beverages'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Products').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
