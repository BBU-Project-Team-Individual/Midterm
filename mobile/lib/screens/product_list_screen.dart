import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_api.dart';
import 'product_form_screen.dart';
import 'category_list_view.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/category_filter.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.api});

  final ProductApi api;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  int _section = 0;
  ProductPage? _page;
  List<Category> _categories = [];
  int? _categoryId;
  String? _error;
  String? _categoryError;
  bool _loading = true;
  bool _loadingCategories = true;
  bool _deleting = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final categories = await widget.api.getCategories();
      if (!mounted) return;
      final resetFilter =
          _categoryId != null &&
          !categories.any((category) => category.id == _categoryId);
      setState(() {
        _categories = categories;
        if (resetFilter) {
          _categoryId = null;
          _page = null;
        }
      });
      if (resetFilter) await _loadProducts();
    } catch (error) {
      if (mounted) setState(() => _categoryError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadProducts({int page = 1}) async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var result = await widget.api.getProducts(
        page: page,
        categoryId: _categoryId,
      );
      if (!mounted || version != _requestVersion) return;
      // Deleting the final row on a page may reduce the page count.
      if (result.currentPage > result.lastPage) {
        result = await widget.api.getProducts(
          page: result.lastPage,
          categoryId: _categoryId,
        );
      }
      if (mounted && version == _requestVersion) setState(() => _page = result);
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openForm([Product? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(api: widget.api, product: product),
      ),
    );
    if (!mounted) return;
    if (saved != true) {
      await _loadCategories();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          product == null ? 'Product created.' : 'Product updated.',
        ),
      ),
    );
    await Future.wait([_loadProducts(), _loadCategories()]);
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '“${product.name}” will be removed from your active inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.api.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product deleted.')));
      await _loadProducts(page: _page?.currentPage ?? 1);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _refreshCatalog() {
    _loadCategories();
    _loadProducts(page: _page?.currentPage ?? 1);
  }

  Widget _stock(Product product) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: product.quantity == 0 ? const Color(0xFFE8E8E8) : AppColors.pale,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '${product.quantity} in stock',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: product.quantity == 0 ? AppColors.ink : AppColors.muted,
      ),
    ),
  );

  Widget _actions(Product product) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Edit ${product.name}',
        onPressed: _loading || _deleting ? null : () => _openForm(product),
        icon: const Icon(Icons.edit_outlined, size: 19),
        color: AppColors.muted,
      ),
      IconButton(
        tooltip: 'Delete ${product.name}',
        onPressed: _loading || _deleting ? null : () => _confirmDelete(product),
        icon: const Icon(Icons.delete_outline, size: 19),
        color: AppColors.muted,
      ),
    ],
  );

  Widget _productRow(Product product, bool wide) {
    final identity = Row(
      children: [
        CatalogImage(image: widget.api.imageUrl(product.image), size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                wide
                    ? '#${product.id.toString().padLeft(4, '0')}'
                    : product.category?.name ?? 'Uncategorized',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Row(
          children: [
            Expanded(flex: 4, child: identity),
            Expanded(
              flex: 2,
              child: Text(
                product.category?.name ?? 'Uncategorized',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _stock(product),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.price,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Cost ${product.cost}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 96, child: _actions(product)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 6),
              _actions(product),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stock(product),
              const Spacer(),
              Text(
                product.price,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _products() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final wide = constraints.maxWidth >= 850;
      final margin = compact ? 20.0 : 32.0;
      final busy = _loading || _deleting;
      final page = _page;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Products',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Manage your products, stock, and prices.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _openForm(),
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: CategoryFilter(
                                categories: _categories,
                                selectedId: _categoryId,
                                enabled: !busy && !_loadingCategories,
                                onChanged: (value) {
                                  setState(() {
                                    _categoryId = value;
                                    _page = null;
                                  });
                                  _loadProducts();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 112,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _categoryId = null;
                                        _page = null;
                                      });
                                      _loadProducts();
                                    },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Text('Clear Filter'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact && page != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        '${page.total} products',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_categoryError != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Notice(
                message: _categoryError!,
                action: TextButton(
                  onPressed: _loadingCategories ? null : _loadCategories,
                  child: const Text('Retry categories'),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Notice(
                message: _error!,
                action: TextButton(
                  onPressed: busy
                      ? null
                      : () => _loadProducts(page: page?.currentPage ?? 1),
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (wide && page != null && page.products.isNotEmpty)
                      Container(
                        color: const Color(0xFFFCFCFC),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 15,
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text('PRODUCT', style: _columnStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('CATEGORY', style: _columnStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('STOCK', style: _columnStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('SELLING PRICE', style: _columnStyle),
                            ),
                            SizedBox(width: 96),
                          ],
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          if (!busy) {
                            await Future.wait([
                              _loadProducts(),
                              _loadCategories(),
                            ]);
                          }
                        },
                        child: page == null || page.products.isEmpty
                            ? LayoutBuilder(
                                builder: (context, size) => ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: size.maxHeight,
                                      child: CatalogEmpty(
                                        title: _loading
                                            ? 'Loading products…'
                                            : _error != null
                                            ? 'Inventory unavailable'
                                            : 'No products yet',
                                        message: _error != null
                                            ? 'Please try refreshing your inventory.'
                                            : _categories.isEmpty
                                            ? 'Create a category first, then add your first product.'
                                            : 'Add your first product and make room for what’s next.',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: page.products.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: AppColors.line,
                                ),
                                itemBuilder: (_, index) =>
                                    _productRow(page.products[index], wide),
                              ),
                      ),
                    ),
                    if (page != null)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.line),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            if (!compact)
                              Expanded(
                                child: Text(
                                  '${page.total} products',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            IconButton(
                              tooltip: 'Previous page',
                              onPressed: busy || page.currentPage <= 1
                                  ? null
                                  : () => _loadProducts(
                                      page: page.currentPage - 1,
                                    ),
                              icon: const Icon(Icons.chevron_left, size: 20),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                'Page ${page.currentPage} of ${page.lastPage}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next page',
                              onPressed:
                                  busy || page.currentPage >= page.lastPage
                                  ? null
                                  : () => _loadProducts(
                                      page: page.currentPage + 1,
                                    ),
                              icon: const Icon(Icons.chevron_right, size: 20),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 16 : 32),
        ],
      );
    },
  );

  static const _columnStyle = TextStyle(
    fontSize: 10,
    letterSpacing: 1,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
  );

  Widget _brand() => const Row(
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.layers_rounded, size: 22, color: Colors.white),
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Text(
          'Midterm',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
            color: AppColors.ink,
          ),
        ),
      ),
    ],
  );

  Widget _navItem(int index, String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        selected: _section == index,
        selectedTileColor: AppColors.pale,
        selectedColor: AppColors.primary,
        textColor: AppColors.muted,
        iconColor: AppColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        leading: Icon(icon, size: 21),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: _section == index ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () => setState(() => _section = index),
      ),
    ),
  );

  Widget _activeTabIcon(IconData icon) => SizedBox(
    width: 32,
    height: 32,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(icon, size: 24, color: AppColors.ink),
        Positioned(
          bottom: 0,
          child: Container(
            width: 16,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1000;
      final content = _section == 0
          ? _products()
          : CategoryListView(api: widget.api, onChanged: _refreshCatalog);
      return Scaffold(
        appBar: desktop
            ? null
            : AppBar(
                title: _brand(),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: AppColors.line),
                ),
              ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                backgroundColor: Colors.white,
                indicatorColor: Colors.transparent,
                selectedIndex: _section,
                onDestinationSelected: (value) =>
                    setState(() => _section = value),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.inventory_2_outlined),
                    selectedIcon: _activeTabIcon(Icons.inventory_2),
                    label: 'Products',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.folder_outlined),
                    selectedIcon: _activeTabIcon(Icons.folder),
                    label: 'Categories',
                  ),
                ],
              ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop)
                Container(
                  width: 224,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: AppColors.line)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _brand(),
                      ),
                      const SizedBox(height: 48),
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 14),
                        child: Text('WORKSPACE', style: _columnStyle),
                      ),
                      _navItem(0, 'Products', Icons.inventory_2_outlined),
                      _navItem(1, 'Categories', Icons.folder_outlined),
                      const Spacer(),
                      const Divider(color: AppColors.line),
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 22,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your workspace',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Inventory management',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    },
  );
}
