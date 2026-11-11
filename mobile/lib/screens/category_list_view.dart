import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_api.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import 'category_form_dialog.dart';

class CategoryListView extends StatefulWidget {
  const CategoryListView({
    super.key,
    required this.api,
    required this.onChanged,
  });
  final ProductApi api;
  final VoidCallback onChanged;

  @override
  State<CategoryListView> createState() => _CategoryListViewState();
}

class _CategoryListViewState extends State<CategoryListView> {
  List<Category> _categories = [];
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.getCategories();
      if (mounted) setState(() => _categories = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Category? category]) async {
    final result = await showCategoryForm(
      context,
      widget.api,
      category: category,
    );
    if (result == null || !mounted) return;
    widget.onChanged();
    await _load();
  }

  Future<void> _delete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete “${category.name}”? Categories with products cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.api.deleteCategory(category.id);
      if (!mounted) return;
      widget.onChanged();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final busy = _loading || _deleting;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 32),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'A place for every product.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : () => _edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Notice(
                message: _error!,
                action: TextButton(
                  onPressed: busy ? null : _load,
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: busy ? () async {} : _load,
              child: _categories.isEmpty
                  ? LayoutBuilder(
                      builder: (context, size) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: size.maxHeight,
                            child: CatalogEmpty(
                              icon: Icons.folder_open_outlined,
                              title: _loading
                                  ? 'Loading categories…'
                                  : _error != null
                                  ? 'Categories unavailable'
                                  : 'No categories yet',
                              message: 'Create a category to organize your products.',
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 20 : 32,
                        0,
                        compact ? 20 : 32,
                        24,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _categories.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 1200
                            ? 3
                            : constraints.maxWidth >= 800
                            ? 2
                            : 1,
                        mainAxisExtent: 112,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CatalogImage(
                                  image: widget.api.imageUrl(category.image),
                                  size: 64,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (category.description
                                              ?.trim()
                                              .isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          category.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Edit ${category.name}',
                                  onPressed: busy
                                      ? null
                                      : () => _edit(category),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                    color: AppColors.muted,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete ${category.name}',
                                  onPressed: busy
                                      ? null
                                      : () => _delete(category),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 19,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    },
  );
}
