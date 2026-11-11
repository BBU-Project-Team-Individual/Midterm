import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:midterm/models/product.dart';
import 'package:midterm/services/product_api.dart';

import 'fixtures.dart';

void main() {
  ProductApi makeApi(MockClient client) {
    final api = ProductApi(client: client, baseUrl: 'http://api.test/api/v1/');
    addTearDown(api.close);
    return api;
  }

  test(
    'reads exact product fields and pagination with server category filter',
    () async {
      final api = makeApi(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/products');
          expect(request.url.queryParameters, {
            'page': '2',
            'per_page': '15',
            'CategoryID': '3',
          });
          expect(request.headers['Accept'], 'application/json');
          return jsonResponse(
            collectionJson([productJson()], page: 2, lastPage: 3, total: 31),
          );
        }),
      );
      final result = await api.getProducts(page: 2, categoryId: 3);
      expect(result.currentPage, 2);
      expect(result.lastPage, 3);
      expect(result.total, 31);
      final product = result.products.single;
      expect(product.id, 1);
      expect(product.cost, '0.25');
      expect(product.price, '0.50');
      expect(product.quantity, 20);
      expect(product.expiryDate, '2027-12-31');
      expect(product.category?.name, 'Beverages');
      expect(product.image, '/images/water.png');
    },
  );

  test('loads every page of categories for the dropdown', () async {
    final pages = <int>[];
    final api = makeApi(
      MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        pages.add(page);
        expect(request.url.queryParameters['per_page'], '100');
        return jsonResponse(
          collectionJson(
            [
              {'category_id': page, 'category_name': 'Category $page'},
            ],
            page: page,
            lastPage: 2,
            total: 2,
          ),
        );
      }),
    );
    final categories = await api.getCategories();
    expect(pages, [1, 2]);
    expect(categories.map((category) => category.id), [1, 2]);
  });

  for (final id in [null, 1]) {
    test(
      '${id == null ? 'creates' : 'updates'} with exact case-sensitive payload and nullable fields',
      () async {
        final api = makeApi(
          MockClient((request) async {
            expect(request.method, id == null ? 'POST' : 'PUT');
            expect(
              request.url.path,
              id == null ? '/api/v1/products' : '/api/v1/products/1',
            );
            expect(
              request.headers['Content-Type'],
              contains('application/json'),
            );
            expect(jsonDecode(request.body), {
              'ProductName': 'ទឹកសុទ្ធ',
              'CategoryID': 3,
              'Qty': 0,
              'UnitPriceIn': '0.25',
              'UnitPriceOut': '0.50',
              'Description': null,
              'Barcode': null,
              'Expiredate': null,
              'ProductImage': null,
            });
            return jsonResponse({
              'data': productJson(name: 'ទឹកសុទ្ធ'),
            }, id == null ? 201 : 200);
          }),
        );
        final product = await api.saveProduct(
          const ProductInput(
            name: 'ទឹកសុទ្ធ',
            categoryId: 3,
            quantity: 0,
            cost: '0.25',
            price: '0.50',
          ),
          id: id,
        );
        expect(product.name, 'ទឹកសុទ្ធ');
      },
    );
  }

  test('preserves Laravel 422 validation errors', () async {
    final api = makeApi(
      MockClient(
        (_) async => jsonResponse({
          'message': 'The barcode has already been taken.',
          'errors': {
            'Barcode': ['The barcode has already been taken.'],
          },
        }, 422),
      ),
    );
    await expectLater(
      api.saveProduct(
        const ProductInput(
          name: 'Water',
          categoryId: 3,
          quantity: 0,
          cost: '0',
          price: '0',
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 422)
            .having(
              (error) => error.errors['Barcode'],
              'barcode error',
              'The barcode has already been taken.',
            ),
      ),
    );
  });

  test('delete accepts an empty 204 response', () async {
    final api = makeApi(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/products/7');
        return http.Response('', 204);
      }),
    );
    await api.deleteProduct(7);
  });

  test('non-JSON server failure becomes a readable error', () async {
    final api = makeApi(
      MockClient((_) async => http.Response('<h1>Error</h1>', 500)),
    );
    await expectLater(
      api.getProducts(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 500),
      ),
    );
  });

  test('connection failure reports configured API address', () async {
    final api = makeApi(
      MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      api.getProducts(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('http://api.test/api/v1'),
        ),
      ),
    );
  });
}
