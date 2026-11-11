import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:midterm/main.dart';
import 'package:midterm/services/product_api.dart';
import 'package:midterm/widgets/catalog_widgets.dart';

import 'fixtures.dart';

void main() {
  testWidgets('missing, empty, and unsupported images show the default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CatalogImage(),
              CatalogImage(image: ''),
              CatalogImage(image: 'file:///old-image.png'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CatalogImagePlaceholder), findsNWidgets(3));
  });

  testWidgets('a category saves without an image and displays the default', (
    tester,
  ) async {
    var created = false;
    final category = {
      'category_id': 9,
      'category_name': 'No photo',
      'image': null,
    };
    final api = ProductApi(
      client: MockClient((request) async {
        expect(request.url.path.endsWith('uploads'), isFalse);
        if (request.url.path.endsWith('categories')) {
          if (request.method == 'POST') {
            expect((jsonDecode(request.body) as Map)['image'], isNull);
            created = true;
            return jsonResponse({'data': category}, 201);
          }
          return jsonResponse(collectionJson(created ? [category] : []));
        }
        return jsonResponse(collectionJson([]));
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('Category image *'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('category_name')),
      'No photo',
    );
    await tester.tap(find.text('Create category'));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(find.text('No photo'), findsOneWidget);
    expect(find.byType(CatalogImagePlaceholder), findsOneWidget);
  });

  testWidgets('removing a category image saves null and restores the default', (
    tester,
  ) async {
    String? image = '/storage/catalog/existing.png';
    var saved = false;
    final api = ProductApi(
      client: MockClient((request) async {
        expect(request.url.path.endsWith('uploads'), isFalse);
        if (request.url.path.endsWith('products')) {
          return jsonResponse(collectionJson([]));
        }
        if (request.method == 'PUT') {
          expect((jsonDecode(request.body) as Map)['image'], isNull);
          image = null;
          saved = true;
          return jsonResponse({
            'data': {
              'category_id': 3,
              'category_name': 'Beverages',
              'image': null,
            },
          });
        }
        return jsonResponse(
          collectionJson([
            {'category_id': 3, 'category_name': 'Beverages', 'image': image},
          ]),
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Beverages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save category'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.byType(CatalogImagePlaceholder), findsOneWidget);
  });

  testWidgets('products without an image display the default thumbnail', (
    tester,
  ) async {
    final api = ProductApi(
      client: MockClient(
        (request) async => request.url.path.endsWith('categories')
            ? categoriesResponse()
            : jsonResponse(
                collectionJson([
                  {...productJson(), 'ProductImage': null},
                ]),
              ),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Mineral Water'), findsOneWidget);
    expect(find.byType(CatalogImagePlaceholder), findsOneWidget);
  });

  testWidgets('sample placeholder URLs use the supplied image in both lists', (
    tester,
  ) async {
    final api = ProductApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('categories')) {
          return jsonResponse(
            collectionJson([
              {
                'category_id': 3,
                'category_name': 'Household',
                'image': 'https://placehold.co/600x400/png?text=Household',
              },
            ]),
          );
        }
        return jsonResponse(
          collectionJson([
            {
              ...productJson(name: 'Hand Soap'),
              'ProductImage':
                  'https://placehold.co/600x400/png?text=Hand%20Soap',
            },
          ]),
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Hand Soap'), findsOneWidget);
    expect(find.byType(CatalogImagePlaceholder), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(CatalogImagePlaceholder),
        matching: find.byType(Image),
      ),
    );
    expect(
      image.image,
      isA<AssetImage>().having(
        (asset) => asset.assetName,
        'default asset',
        'assets/images/default_image.png',
      ),
    );
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    expect(find.text('Household'), findsOneWidget);
    expect(find.byType(CatalogImagePlaceholder), findsOneWidget);
  });
}
