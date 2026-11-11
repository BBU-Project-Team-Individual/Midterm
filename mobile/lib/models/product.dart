class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.image,
  });

  final int id;
  final String name;
  final String? description;
  final String? image;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: (json['category_id'] as num).toInt(),
    name: json['category_name'] as String,
    description: json['description'] as String?,
    image: json['image'] as String?,
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.quantity,
    required this.cost,
    required this.price,
    this.description,
    this.barcode,
    this.expiryDate,
    this.image,
    this.category,
  });

  final int id;
  final String name;
  final int categoryId;
  final int quantity;
  // Laravel decimal casts return strings. Keep them exact for editing/saving.
  final String cost;
  final String price;
  final String? description;
  final String? barcode;
  final String? expiryDate;
  final String? image;
  final Category? category;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['ProductID'] as num).toInt(),
    name: json['ProductName'] as String,
    categoryId: (json['CategoryID'] as num).toInt(),
    quantity: (json['Qty'] as num).toInt(),
    cost: json['UnitPriceIn'].toString(),
    price: json['UnitPriceOut'].toString(),
    description: json['Description'] as String?,
    barcode: json['Barcode'] as String?,
    expiryDate: json['Expiredate'] as String?,
    image: json['ProductImage'] as String?,
    category: json['category'] is Map<String, dynamic>
        ? Category.fromJson(json['category'] as Map<String, dynamic>)
        : null,
  );
}

class ProductPage {
  const ProductPage({
    required this.products,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<Product> products;
  final int currentPage;
  final int lastPage;
  final int total;

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return ProductPage(
      products: (json['data'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentPage: (meta['current_page'] as num).toInt(),
      lastPage: (meta['last_page'] as num).toInt(),
      total: (meta['total'] as num).toInt(),
    );
  }
}

class ProductInput {
  const ProductInput({
    required this.name,
    required this.categoryId,
    required this.quantity,
    required this.cost,
    required this.price,
    this.description,
    this.barcode,
    this.expiryDate,
    this.image,
  });

  final String name;
  final int categoryId;
  final int quantity;
  final String cost;
  final String price;
  final String? description;
  final String? barcode;
  final String? expiryDate;
  final String? image;

  Map<String, dynamic> toJson() => {
    'ProductName': name,
    'Description': description,
    'CategoryID': categoryId,
    'Barcode': barcode,
    'Expiredate': expiryDate,
    'Qty': quantity,
    'UnitPriceIn': cost,
    'UnitPriceOut': price,
    'ProductImage': image,
  };
}
