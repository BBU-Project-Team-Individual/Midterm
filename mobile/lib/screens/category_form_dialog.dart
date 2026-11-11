import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/selected_image.dart';
import '../services/product_api.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/image_picker_field.dart';

Future<Category?> showCategoryForm(
  BuildContext context,
  ProductApi api, {
  Category? category,
}) => showDialog<Category>(
  context: context,
  barrierDismissible: false,
  builder: (_) => CategoryFormDialog(api: api, category: category),
);

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({super.key, required this.api, this.category});
  final ProductApi api;
  final Category? category;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late final _image = TextEditingController(text: widget.category?.image);
  bool _saving = false;
  String? _error;
  Map<String, String> _errors = {};
  SelectedImage? _selectedImage;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _errors = {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_selectedImage != null) {
        final path = await widget.api.uploadImage(_selectedImage!);
        if (!mounted) return;
        setState(() {
          _image.text = path;
          _selectedImage = null;
        });
      }
      final category = await widget.api.saveCategory(
        id: widget.category?.id,
        name: _name.text.trim(),
        image: _image.text.trim().isEmpty ? null : _image.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(category);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _errors = Map.of(error.errors);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _apiKey(String key) => switch (key) {
    'category_image' => 'image',
    'category_description' => 'description',
    _ => key,
  };

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    int max = 255,
    bool required = false,
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_saving,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 2,
        errorText: _errors[_apiKey(key)],
      ),
      onChanged: (_) {
        if (_errors.containsKey(_apiKey(key))) {
          setState(() => _errors.remove(_apiKey(key)));
        }
      },
      validator: (value) {
        final text = (value ?? '').trim();
        if (required && text.isEmpty) return 'This field is required.';
        if (text.runes.length > max) return 'Use $max characters or fewer.';
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      title: Row(
        children: [
          const Icon(
            Icons.create_new_folder_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.category == null ? 'New category' : 'Edit category',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Give similar products a home.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                if (_error != null) Notice(message: _error!),
                _field(
                  'category_name',
                  'Category name *',
                  _name,
                  max: 50,
                  required: true,
                ),
                _field(
                  'category_description',
                  'Description',
                  _description,
                  lines: 3,
                ),
                ImagePickerField(
                  key: const ValueKey('category_image'),
                  label: 'Category image',
                  value: _selectedImage,
                  existingImageUrl: widget.api.imageUrl(_image.text),
                  enabled: !_saving,
                  uploading: _saving && _selectedImage != null,
                  errorText: _errors['image'],
                  onChanged: (image) => setState(() {
                    _selectedImage = image;
                    if (image == null) _image.clear();
                    _errors.remove('image');
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Saving…'
                : widget.category == null
                ? 'Create category'
                : 'Save category',
          ),
        ),
      ],
    ),
  );
}
