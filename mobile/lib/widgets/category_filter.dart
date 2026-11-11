import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
    this.includeAll = true,
    this.buttonKey = const ValueKey('category-filter'),
  });

  final List<Category> categories;
  final int? selectedId;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final bool includeAll;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final selected = categories.where((category) => category.id == selectedId);
    final label = selected.isEmpty
        ? includeAll
              ? 'All categories'
              : 'Select category'
        : selected.first.name;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return PopupMenuButton<int>(
          key: buttonKey,
          enabled: enabled,
          tooltip: 'Choose category',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: .08),
          elevation: 2,
          menuPadding: const EdgeInsets.all(6),
          borderRadius: BorderRadius.circular(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.line),
          ),
          constraints: BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: 360,
          ),
          onSelected: (value) => onChanged(value == 0 ? null : value),
          itemBuilder: (_) => [
            if (includeAll) _item(0, 'All categories'),
            ...categories.map((category) => _item(category.id, category.name)),
          ],
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (includeAll) ...[
                  const Icon(
                    Icons.filter_list,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: enabled ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<int> _item(int value, String label) {
    final selected = value == (selectedId ?? 0);
    return PopupMenuItem<int>(
      value: value,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 18,
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.ink,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
