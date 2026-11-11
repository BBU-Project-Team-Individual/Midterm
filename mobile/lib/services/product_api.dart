import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/selected_image.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> errors;

  @override
  String toString() => message;
}

class ProductApi {
  ProductApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    final host =
        !foundation.kIsWeb &&
            foundation.defaultTargetPlatform ==
                foundation.TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    return 'http://$host:8001/api/v1';
  }

  final http.Client _client;
  final String baseUrl;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    return _send(request);
  }

  Future<Map<String, dynamic>> _send(http.BaseRequest request) async {
    try {
      final response =
          await (() async {
            return http.Response.fromStream(await _client.send(request));
          })().timeout(
            Duration(seconds: request is http.MultipartRequest ? 60 : 20),
          );
      if (response.statusCode == 204) return {};

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        // A proxy/server may return HTML instead of Laravel JSON.
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errors = <String, String>{};
        final rawErrors = payload?['errors'];
        if (rawErrors is Map) {
          for (final entry in rawErrors.entries) {
            errors[entry.key.toString()] = entry.value is List
                ? (entry.value as List).join('\n')
                : entry.value.toString();
          }
        }
        throw ApiException(
          payload?['message'] as String? ??
              'The server returned an error (${response.statusCode}). Please try again.',
          statusCode: response.statusCode,
          errors: errors,
        );
      }
      if (payload == null) {
        throw const ApiException(
          'The server returned an invalid JSON response.',
        );
      }
      return payload;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Refresh to check the latest data before trying again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not connect to $baseUrl. Check that the API is running and reachable from this device.',
      );
    }
  }

  Future<ProductPage> getProducts({int page = 1, int? categoryId}) async {
    return ProductPage.fromJson(
      await _request(
        'GET',
        'products',
        query: {
          'page': '$page',
          'per_page': '15',
          if (categoryId != null) 'CategoryID': '$categoryId',
        },
      ),
    );
  }

  Future<String> uploadImage(SelectedImage image) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'))
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          image.bytes,
          filename: image.uploadName,
        ),
      );
    late final Map<String, dynamic> json;
    try {
      json = await _send(request);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw const ApiException(
          'Image uploads are not enabled on the server yet.',
          statusCode: 404,
        );
      }
      rethrow;
    }
    final path = (json['data'] as Map<String, dynamic>?)?['path'];
    if (path is! String || !path.startsWith('/storage/')) {
      throw const ApiException(
        'The server did not return the uploaded image. Please try again.',
      );
    }
    return path;
  }

  String? imageUrl(String? image) {
    if (image == null || image.trim().isEmpty) return null;
    final uri = Uri.tryParse(image);
    if (uri == null) return null;
    // Sample seed data used this image generator instead of real photos.
    if (uri.host.toLowerCase() == 'placehold.co') return null;
    if (uri.scheme == 'http' || uri.scheme == 'https') return image;
    if (uri.hasScheme) return null;
    return Uri.parse(baseUrl)
        .resolve(image.startsWith('/') ? image : '/$image')
        .toString();
  }

  Future<List<Category>> getCategories() async {
    final categories = <Category>[];
    var page = 1;
    var lastPage = 1;
    do {
      final json = await _request(
        'GET',
        'categories',
        query: {'page': '$page', 'per_page': '100'},
      );
      categories.addAll(
        (json['data'] as List).map(
          (item) => Category.fromJson(item as Map<String, dynamic>),
        ),
      );
      lastPage = ((json['meta'] as Map<String, dynamic>)['last_page'] as num)
          .toInt();
      page++;
    } while (page <= lastPage);
    return categories;
  }

  Future<Product> saveProduct(ProductInput input, {int? id}) async {
    final json = await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? 'products' : 'products/$id',
      body: input.toJson(),
    );
    return Product.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Category> saveCategory({
    int? id,
    required String name,
    String? image,
    String? description,
  }) async {
    final json = await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? 'categories' : 'categories/$id',
      body: {'category_name': name, 'description': description, 'image': image},
    );
    return Category.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) async {
    await _request('DELETE', 'categories/$id');
  }

  Future<void> deleteProduct(int id) async {
    await _request('DELETE', 'products/$id');
  }

  void close() => _client.close();
}
