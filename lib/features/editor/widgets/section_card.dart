import 'package:flutter/material.dart';

import '../../../core/models/item.dart';

/// Visual divider for a [PageBreakItemContent] — represents a new section.
class SectionCard extends StatelessWidget {
  final Item item;

  const SectionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = item.title?.isNotEmpty == true;
    final hasDesc = item.description?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.primary)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.horizontal_rule,
                    size: 16, color: theme.colorScheme.primary),
              ),
              Expanded(child: Divider(color: theme.colorScheme.primary)),
            ],
          ),
          if (hasTitle || hasDesc)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle)
                    Text(
                      item.title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (hasDesc) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Inert text block ([TextItemContent]).
class TextBlockCard extends StatelessWidget {
  final Item item;

  const TextBlockCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.title?.isNotEmpty == true)
              Text(item.title!,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            if (item.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(item.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
