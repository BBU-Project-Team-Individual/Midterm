import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    ),
  );
}

class CatalogEmpty extends StatelessWidget {
  const CatalogEmpty({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.inventory_2_outlined,
  });
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.pale,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.pale,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.ink, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.ink, fontSize: 13),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class CatalogImagePlaceholder extends StatelessWidget {
  const CatalogImagePlaceholder({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Default image',
    image: true,
    child: Image.asset(
      'assets/images/default_image.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    ),
  );
}

class CatalogImage extends StatelessWidget {
  const CatalogImage({super.key, this.image, this.size = 48});
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(image ?? '');
    final valid =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final placeholder = CatalogImagePlaceholder(size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: valid
            ? Image.network(
                image!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : placeholder,
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}
