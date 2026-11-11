import 'dart:convert';

import 'package:http/http.dart' as http;

Map<String, dynamic> productJson({int id = 1, String name = 'Mineral Water'}) =>
    {
      'ProductID': id,
      'ProductName': name,
      'Description': 'Fresh water',
      'CategoryID': 3,
      'Barcode': '1234567890',
      'Expiredate': '2027-12-31',
      'Qty': 20,
      'UnitPriceIn': '0.25',
      'UnitPriceOut': '0.50',
      'ProductImage': '/images/water.png',
      'isDeleted': false,
      'category': {
        'category_id': 3,
        'category_name': 'Beverages',
        'image': '/images/beverages.png',
        'description': 'Drinks and refreshments',
      },
    };

Map<String, dynamic> collectionJson(
  List<Map<String, dynamic>> data, {
  int page = 1,
  int lastPage = 1,
  int? total,
}) => {
  'data': data,
  'meta': {
    'current_page': page,
    'last_page': lastPage,
    'total': total ?? data.length,
  },
  'links': {'next': null, 'prev': null},
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response categoriesResponse() => jsonResponse(
  collectionJson([
    {
      'category_id': 3,
      'category_name': 'Beverages',
      'image': '/images/beverages.png',
      'description': 'Drinks and refreshments',
    },
    {'category_id': 4, 'category_name': 'Food', 'image': '/images/food.png'},
  ]),
);
