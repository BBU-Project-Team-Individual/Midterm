import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/selected_image.dart';
import '../services/product_api.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/image_picker_field.dart';
import '../widgets/category_filter.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.api, this.product});

  final ProductApi api;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late final Map<String, TextEditingController> _fields;
  List<Category> _categories = [];
  Map<String, String> _errors = {};
  int? _categoryId;
  bool _loadingCategories = true;
  bool _saving = false;
  String? _categoryError;
  String? _saveError;
  SelectedImage? _selectedImage;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _categoryId = product?.categoryId;
    _fields = {
      'ProductName': TextEditingController(text: product?.name),
      'Description': TextEditingController(text: product?.description),
      'Barcode': TextEditingController(text: product?.barcode),
      'Expiredate': TextEditingController(text: product?.expiryDate),
      'Qty': TextEditingController(text: '${product?.quantity ?? 0}'),
      'UnitPriceIn': TextEditingController(text: product?.cost ?? '0.00'),
      'UnitPriceOut': TextEditingController(text: product?.price ?? '0.00'),
      'ProductImage': TextEditingController(text: product?.image),
    };
    _loadCategories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final categories = await widget.api.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (!categories.any((category) => category.id == _categoryId)) {
          _categoryId = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _categoryError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  String _value(String field) => _fields[field]!.text.trim();

  String? _nullable(String field) {
    final value = _value(field);
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _errors = {};
      _saveError = null;
    });
    if (!_formKey.currentState!.validate()) {
      _scrollToTop();
      return;
    }
    setState(() => _saving = true);
    try {
      if (_selectedImage != null) {
        final path = await widget.api.uploadImage(_selectedImage!);
        if (!mounted) return;
        setState(() {
          _fields['ProductImage']!.text = path;
          _selectedImage = null;
        });
      }
      await widget.api.saveProduct(
        ProductInput(
          name: _value('ProductName'),
          categoryId: _categoryId!,
          quantity: int.parse(_value('Qty')),
          cost: _value('UnitPriceIn'),
          price: _value('UnitPriceOut'),
          description: _nullable('Description'),
          barcode: _nullable('Barcode'),
          expiryDate: _nullable('Expiredate'),
          image: _nullable('ProductImage'),
        ),
        id: widget.product?.id,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errors = Map.of(error.errors);
        _saveError = error.message;
      });
      _scrollToTop();
    } catch (error) {
      if (mounted) setState(() => _saveError = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickDate() async {
    final existing = DateTime.tryParse(_value('Expiredate'));
    final date = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      _fields['Expiredate']!.text =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      _errors.remove('Expiredate');
    });
  }

  String? _validatePrice(String? input) {
    final value = (input ?? '').trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
      return 'Enter a non-negative amount with up to 2 decimals.';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount > 99999999.99) {
      return 'Maximum amount is 99999999.99.';
    }
    return null;
  }

  Widget _field(
    String field,
    String label, {
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: TextFormField(
        key: ValueKey(field),
        controller: _fields[field],
        enabled: !_saving,
        maxLines: maxLines,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          errorText: _errors[field],
        ),
        onChanged: (_) {
          if (_errors.containsKey(field)) {
            setState(() => _errors.remove(field));
          }
        },
        validator: (value) {
          if (maxLength != null &&
              (value ?? '').trim().runes.length > maxLength) {
            return 'Use $maxLength characters or fewer.';
          }
          return validator?.call(value);
        },
      ),
    );
  }

  Widget _stack(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        children[i],
      ],
    ],
  );

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, size) => size.maxWidth < 460
        ? _stack([first, second])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 20),
              Expanded(child: second),
            ],
          ),
  );

  Widget _categoryField() {
    if (_loadingCategories) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Loading categories',
      );
    }
    if (_categoryError != null) {
      return Notice(
        message: _categoryError!,
        action: TextButton(
          onPressed: _loadCategories,
          child: const Text('Retry categories'),
        ),
      );
    }
    if (_categories.isEmpty) {
      return const Text(
        'No categories yet. Add one from the Categories page.',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      );
    }
    return FormField<int>(
      key: const ValueKey('CategoryID'),
      initialValue: _categoryId,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => value == null ? 'Select a category.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category *', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: CategoryFilter(
                buttonKey: const ValueKey('category-picker'),
                categories: _categories,
                selectedId: field.value,
                enabled: !_saving,
                includeAll: false,
                onChanged: (value) {
                  field.didChange(value);
                  setState(() {
                    _categoryId = value;
                    _errors.remove('CategoryID');
                  });
                },
              ),
            ),
          ),
          if (_errors['CategoryID'] ?? field.errorText case final String error)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error,
                style: const TextStyle(fontSize: 12, color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _expiryField() => TextFormField(
    key: const ValueKey('Expiredate'),
    controller: _fields['Expiredate'],
    readOnly: true,
    enabled: !_saving,
    onTap: _pickDate,
    decoration: InputDecoration(
      labelText: 'Expiry date',
      hintText: 'YYYY-MM-DD',
      errorText: _errors['Expiredate'],
      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 19),
      suffixIcon: _value('Expiredate').isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear expiry date',
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _fields['Expiredate']!.clear();
                      _errors.remove('Expiredate');
                    }),
              icon: const Icon(Icons.close, size: 18),
            ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            editing ? 'Edit product' : 'Add product',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.line),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed:
                              _saving ||
                                  _loadingCategories ||
                                  _categoryError != null ||
                                  _categories.isEmpty
                              ? null
                              : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            _saving
                                ? 'Saving…'
                                : editing
                                ? 'Save changes'
                                : 'Create product',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: _stack([
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Fields marked * are required.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_saveError != null) Notice(message: _saveError!),
                  SectionCard(
                    title: 'Product details',
                    subtitle: 'The basics that make your product easy to find.',
                    icon: Icons.inventory_2_outlined,
                    child: _stack([
                      _field(
                        'ProductName',
                        'Product name *',
                        maxLength: 100,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter a product name.'
                            : null,
                      ),
                      _categoryField(),
                      _field(
                        'Description',
                        'Description',
                        maxLength: 255,
                        maxLines: 3,
                      ),
                    ]),
                  ),
                  SectionCard(
                    title: 'Stock & pricing',
                    subtitle: 'Set your available quantity and price per unit.',
                    icon: Icons.payments_outlined,
                    child: _stack([
                      _field(
                        'Qty',
                        'Quantity *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          final number = int.tryParse(text);
                          return !RegExp(r'^\d+$').hasMatch(text) ||
                                  number == null ||
                                  number > 2147483647
                              ? 'Enter a whole number from 0 to 2147483647.'
                              : null;
                        },
                      ),
                      _pair(
                        _field(
                          'UnitPriceIn',
                          'Unit cost *',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _validatePrice,
                        ),
                        _field(
                          'UnitPriceOut',
                          'Selling price *',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _validatePrice,
                        ),
                      ),
                    ]),
                  ),
                  SectionCard(
                    title: 'Additional details',
                    subtitle:
                        'Optional information for tracking and presentation.',
                    icon: Icons.tune_outlined,
                    child: _stack([
                      _pair(
                        _field('Barcode', 'Barcode', maxLength: 255),
                        _expiryField(),
                      ),
                      ImagePickerField(
                        key: const ValueKey('ProductImage'),
                        label: 'Product image',
                        value: _selectedImage,
                        existingImageUrl: widget.api.imageUrl(
                          _nullable('ProductImage'),
                        ),
                        enabled: !_saving,
                        uploading: _saving && _selectedImage != null,
                        errorText: _errors['ProductImage'] ?? _errors['image'],
                        onChanged: (image) => setState(() {
                          _selectedImage = image;
                          if (image == null) _fields['ProductImage']!.clear();
                          _errors.remove('ProductImage');
                          _errors.remove('image');
                        }),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
