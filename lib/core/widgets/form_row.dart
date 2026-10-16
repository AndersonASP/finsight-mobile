import 'package:flutter/material.dart';

/// A single row in the reference app's flat-list form style: an icon, a
/// label or free-form child, an optional trailing value, and a chevron when
/// the row is tappable. Used by every "nova X" form so they all look alike.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.leading,
    this.title,
    this.trailingText,
    this.leadingDot,
    this.onTap,
    this.child,
  });

  final Widget leading;
  final String? title;
  final String? trailingText;
  final Color? leadingDot;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 16),
          Expanded(
            child:
                child ??
                Row(
                  children: [
                    if (leadingDot != null) ...[
                      CircleAvatar(backgroundColor: leadingDot, radius: 6),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      title ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
          ),
          if (trailingText != null)
            Text(trailingText!, style: Theme.of(context).textTheme.bodyLarge),
          if (onTap != null)
            Icon(
              Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
