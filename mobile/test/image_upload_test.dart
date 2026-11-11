import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:midterm/main.dart';
import 'package:midterm/models/selected_image.dart';
import 'package:midterm/services/device_image_picker.dart';
import 'package:midterm/services/product_api.dart';
import 'package:midterm/widgets/image_picker_field.dart';

import 'fixtures.dart';
import 'image_helpers.dart';

void main() {
  ProductApi makeApi(Future<http.Response> Function(http.Request) handler) {
    final api = ProductApi(
      client: MockClient(handler),
      baseUrl: 'http://api.test:8001/api/v1',
    );
    addTearDown(api.close);
    return api;
  }

  test('uploads image bytes as multipart and reads its storage path', () async {
    final api = makeApi((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/uploads');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.headers['accept'], 'application/json');
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="image"; filename="image.png"'));
      expect(body, contains(latin1.decode(testImageBytes())));
      return jsonResponse({
        'data': {'path': '/storage/catalog/photo.png'},
      }, 201);
    });
    final image = SelectedImage.fromBytes(
      name: 'My photo.png',
      bytes: testImageBytes(),
    );
    expect(await api.uploadImage(image), '/storage/catalog/photo.png');
  });

  test('resolves storage images against the configured device API host', () {
    final api = makeApi((_) async => http.Response('', 204));
    expect(
      api.imageUrl('/storage/catalog/photo.png'),
      'http://api.test:8001/storage/catalog/photo.png',
    );
    expect(
      api.imageUrl('storage/catalog/photo.png'),
      'http://api.test:8001/storage/catalog/photo.png',
    );
    expect(
      api.imageUrl('https://images.test/photo.png'),
      'https://images.test/photo.png',
    );
    expect(api.imageUrl('file:///private/photo.png'), isNull);
    expect(api.imageUrl(''), isNull);
    expect(
      api.imageUrl('https://placehold.co/600x400/png?text=Hand%20Soap'),
      isNull,
    );
  });

  test('does not accept a missing upload path from the server', () async {
    final api = makeApi((_) async => jsonResponse({'data': {}}, 201));
    await expectLater(
      api.uploadImage(
        SelectedImage.fromBytes(name: 'photo.png', bytes: testImageBytes()),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('canceling the native picker returns no new image', () async {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = FakeImageSelector();
    addTearDown(() => FileSelectorPlatform.instance = original);
    expect(await chooseDeviceImage(), isNull);
  });

  test('checks image contents instead of trusting a filename', () {
    expect(
      () => SelectedImage.fromBytes(
        name: 'photo.jpg',
        bytes: Uint8List.fromList('not an image'.codeUnits),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('JPG, PNG, or WebP'),
        ),
      ),
    );
    expect(
      SelectedImage.fromBytes(
        name: 'renamed.txt',
        bytes: testImageBytes(),
      ).uploadName,
      'image.png',
    );
  });

  test('rejects empty and oversized image selections', () {
    expect(
      () => SelectedImage.fromBytes(name: 'empty.png', bytes: Uint8List(0)),
      throwsFormatException,
    );
    expect(
      () => SelectedImage.fromBytes(
        name: 'big.png',
        bytes: Uint8List(SelectedImage.maxBytes + 1),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('5 MB'),
        ),
      ),
    );
  });

  Future<void> openEdit(WidgetTester tester, ProductApi api) async {
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Mineral Water'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ImagePickerField));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'missing native picker gives restart instructions and stays usable',
    (tester) async {
      final original = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = FakeImageSelector(
        error: PlatformException(code: 'channel-error'),
      );
      addTearDown(() => FileSelectorPlatform.instance = original);
      final api = makeApi(
        (request) async => request.url.path.endsWith('categories')
            ? categoriesResponse()
            : jsonResponse(collectionJson([productJson()])),
      );
      await openEdit(tester, api);
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Stop the app completely and run it again to enable image selection.',
        ),
        findsWidgets,
      );
      expect(find.text('Change image'), findsOneWidget);
      expect(find.text('Opening…'), findsNothing);
    },
  );

  testWidgets(
    'product save uploads once and reuses path after validation retry',
    (tester) async {
      useTestImagePicker(addTearDown);
      var uploads = 0;
      var saves = 0;
      final api = makeApi((request) async {
        if (request.url.path.endsWith('categories')) {
          return categoriesResponse();
        }
        if (request.url.path.endsWith('uploads')) {
          uploads++;
          return jsonResponse({
            'data': {'path': '/storage/catalog/new.png'},
          }, 201);
        }
        if (request.method == 'PUT') {
          saves++;
          expect(
            (jsonDecode(request.body) as Map)['ProductImage'],
            '/storage/catalog/new.png',
          );
          if (saves == 1) {
            return jsonResponse({
              'message': 'Check your barcode.',
              'errors': {
                'Barcode': ['Already used.'],
              },
            }, 422);
          }
          return jsonResponse({
            'data': {
              ...productJson(),
              'ProductImage': '/storage/catalog/new.png',
            },
          });
        }
        return jsonResponse(collectionJson([productJson()]));
      });
      await openEdit(tester, api);
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      expect(find.text('photo.png'), findsOneWidget);
      expect(uploads, 0);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(saves, 1);
      expect(find.text('Check your barcode.'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(saves, 2);
    },
  );

  testWidgets('upload failure keeps chosen image and prevents product writes', (
    tester,
  ) async {
    useTestImagePicker(addTearDown);
    var writes = 0;
    final api = makeApi((request) async {
      if (request.url.path.endsWith('categories')) return categoriesResponse();
      if (request.url.path.endsWith('uploads')) {
        return jsonResponse({
          'message': 'Image rejected.',
          'errors': {
            'image': ['Choose a different image.'],
          },
        }, 422);
      }
      if (request.method == 'PUT') writes++;
      return jsonResponse(collectionJson([productJson()]));
    });
    await openEdit(tester, api);
    await tester.tap(find.text('Change image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('Choose a different image.'), findsOneWidget);
  });

  testWidgets(
    'removing a product image clears its stored reference without uploading',
    (tester) async {
      var saved = false;
      final api = makeApi((request) async {
        if (request.url.path.endsWith('categories')) {
          return categoriesResponse();
        }
        expect(request.url.path.endsWith('uploads'), isFalse);
        if (request.method == 'PUT') {
          expect((jsonDecode(request.body) as Map)['ProductImage'], isNull);
          saved = true;
          return jsonResponse({
            'data': {...productJson(), 'ProductImage': null},
          });
        }
        return jsonResponse(collectionJson([productJson()]));
      });
      await openEdit(tester, api);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
    },
  );
}
