import 'package:flutter/material.dart';

import 'screens/product_list_screen.dart';
import 'services/product_api.dart';
import 'theme/app_theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.api});

  final ProductApi? api;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ProductApi _api = widget.api ?? ProductApi();

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midterm',
      debugShowCheckedModeBanner: false,
      theme: inventoryTheme(),
      home: ProductListScreen(api: _api),
    );
  }
}
