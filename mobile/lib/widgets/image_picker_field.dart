import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/selected_image.dart';
import '../services/device_image_picker.dart';
import '../theme/app_theme.dart';
import 'catalog_widgets.dart';

class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.existingImageUrl,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.uploading = false,
    this.errorText,
  });

  final String label;
  final SelectedImage? value;
  final String? existingImageUrl;
  final ValueChanged<SelectedImage?> onChanged;
  final bool required;
  final bool enabled;
  final bool uploading;
  final String? errorText;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _picking = false;
  String? _selectionError;

  void _showPickerError(String message) {
    if (!mounted) return;
    setState(() => _selectionError = message);
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose(FormFieldState<bool> field) async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _selectionError = null;
    });
    try {
      final image = await chooseDeviceImage();
      if (!mounted || image == null) return;
      widget.onChanged(image);
      field.didChange(true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _selectionError = error.message);
    } on MissingPluginException {
      _showPickerError(
        'Stop the app completely and run it again to enable image selection.',
      );
    } on PlatformException catch (error) {
      _showPickerError(
        error.code == 'channel-error'
            ? 'Stop the app completely and run it again to enable image selection.'
            : 'Could not open the image chooser. Please try again.',
      );
    } catch (_) {
      _showPickerError('Could not open the image chooser. Please try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormField<bool>(
    validator: (_) {
      if (_picking) return 'Please wait for the selected image.';
      if (_selectionError != null) return _selectionError;
      if (widget.required &&
          widget.value == null &&
          widget.existingImageUrl == null) {
        return 'Choose an image.';
      }
      return null;
    },
    builder: (field) {
      final hasImage = widget.value != null || widget.existingImageUrl != null;
      final enabled = widget.enabled && !_picking;
      const placeholder = CatalogImagePlaceholder(size: 72);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.label}${widget.required ? ' *' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 72,
                    child: widget.value != null
                        ? Image.memory(
                            widget.value!.bytes,
                            fit: BoxFit.cover,
                            cacheWidth: 216,
                            errorBuilder: (_, _, _) => placeholder,
                          )
                        : widget.existingImageUrl != null
                        ? Image.network(
                            widget.existingImageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 216,
                            errorBuilder: (_, _, _) => placeholder,
                          )
                        : placeholder,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasImage)
                        Text(
                          widget.value?.name ?? 'Current image',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      if (hasImage) const SizedBox(height: 6),
                      if (widget.uploading || _picking)
                        Row(
                          children: [
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.uploading ? 'Uploading…' : 'Opening…',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            OutlinedButton(
                              onPressed: enabled ? () => _choose(field) : null,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: Text(
                                hasImage ? 'Change image' : 'Choose image',
                              ),
                            ),
                            if (hasImage)
                              TextButton(
                                onPressed: enabled
                                    ? () {
                                        setState(() => _selectionError = null);
                                        widget.onChanged(null);
                                        field.didChange(false);
                                      }
                                    : null,
                                child: const Text('Remove'),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'JPG, PNG or WebP · Up to 5 MB',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.errorText ?? _selectionError ?? field.errorText
              case final String error)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      );
    },
  );
}
