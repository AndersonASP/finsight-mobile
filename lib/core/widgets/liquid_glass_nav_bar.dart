import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LiquidGlassNavItem {
  const LiquidGlassNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// A floating, frosted-glass bottom bar in the spirit of Apple's "Liquid
/// Glass": a pill of tabs whose selection blob slides (and can be dragged)
/// between items, plus a separate round glass button for the main action.
///
/// Meant for `Scaffold(extendBody: true, bottomNavigationBar: ...)`, so the
/// page scrolls *behind* the glass and the blur has something to show.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final List<LiquidGlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final IconData actionIcon;

  /// Read by screen readers (the action button shows only its icon).
  final String actionLabel;
  final VoidCallback onAction;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset > 0 ? bottomInset : 12,
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: _TabsPill(
                items: items,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
              ),
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: actionIcon,
              label: actionLabel,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// The frosted surface shared by the pill and the round button: blurred and
/// slightly over-saturated backdrop, a faint top-lit tint, a specular rim
/// (bright top-left, fading out) and a soft shadow underneath.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  static final _saturate = ColorFilter.matrix(_saturationMatrix(1.7));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? const Color(0xFF1C1F24).withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.62);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            inner: _saturate,
          ),
          child: CustomPaint(
            foregroundPainter: _RimPainter(
              borderRadius: borderRadius,
              isDark: isDark,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: isDark ? 0.06 : 0.25),
                      fill,
                    ),
                    fill,
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The thin light-catching edge that sells the "glass" look.
class _RimPainter extends CustomPainter {
  _RimPainter({required this.borderRadius, required this.isDark});

  final BorderRadius borderRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.35 : 0.9),
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.25),
          Colors.white.withValues(alpha: isDark ? 0.18 : 0.5),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.isDark != isDark || old.borderRadius != borderRadius;
}

class _TabsPill extends StatefulWidget {
  const _TabsPill({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<LiquidGlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_TabsPill> createState() => _TabsPillState();
}

class _TabsPillState extends State<_TabsPill> {
  static const _inset = 5.0;

  /// Finger position while dragging across the pill; null when not dragging.
  double? _dragX;
  int? _hoverIndex;

  int _indexAt(double x, double itemWidth) =>
      ((x - _inset) / itemWidth).floor().clamp(0, widget.items.length - 1);

  void _select(int index) {
    if (index != widget.selectedIndex) {
      HapticFeedback.selectionClick();
      widget.onSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LiquidGlassNavBar.height / 2);
    return _GlassSurface(
      borderRadius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              (constraints.maxWidth - _inset * 2) / widget.items.length;
          final dragging = _dragX != null;
          final blobLeft = dragging
              ? (_dragX! - itemWidth / 2).clamp(
                  _inset,
                  constraints.maxWidth - _inset - itemWidth,
                )
              : _inset + widget.selectedIndex * itemWidth;
          final highlighted = _hoverIndex ?? widget.selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _select(_indexAt(d.localPosition.dx, itemWidth)),
            onHorizontalDragStart: (d) => setState(() {
              _dragX = d.localPosition.dx;
              _hoverIndex = _indexAt(_dragX!, itemWidth);
            }),
            onHorizontalDragUpdate: (d) => setState(() {
              _dragX = d.localPosition.dx;
              final index = _indexAt(_dragX!, itemWidth);
              if (index != _hoverIndex) HapticFeedback.selectionClick();
              _hoverIndex = index;
            }),
            onHorizontalDragEnd: (_) {
              final index = _hoverIndex ?? widget.selectedIndex;
              setState(() {
                _dragX = null;
                _hoverIndex = null;
              });
              if (index != widget.selectedIndex) widget.onSelected(index);
            },
            child: Stack(
              children: [
                AnimatedPositioned(
                  // Follows the finger 1:1 while dragging; springs into
                  // place (with a little overshoot) when released or tapped.
                  duration: dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  left: blobLeft,
                  top: _inset,
                  bottom: _inset,
                  width: itemWidth,
                  child: AnimatedScale(
                    // "Lifts" like a drop of liquid while being dragged.
                    scale: dragging ? 1.08 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: _SelectionBlob(lifted: dragging),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      SizedBox(
                        width: itemWidth + (i == 0 ? _inset : 0),
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? _inset : 0),
                          child: _TabItem(
                            item: widget.items[i],
                            selected: i == highlighted,
                            onTap: () => _select(i),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectionBlob extends StatelessWidget {
  const _SelectionBlob({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LiquidGlassNavBar.height),
        color: isDark
            ? Colors.black.withValues(alpha: lifted ? 0.25 : 0.4)
            : Color.alphaBlend(
                primary.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: lifted ? 0.55 : 0.8),
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.9),
        ),
        boxShadow: lifted
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LiquidGlassNavItem item;
  final bool selected;

  /// Only for screen readers — touches are handled by the whole pill, so a
  /// drag can start anywhere on it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: const Duration(milliseconds: 200),
            child: Icon(item.icon, color: color, size: 24),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(item.label, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: SizedBox.square(
            dimension: LiquidGlassNavBar.height,
            child: _GlassSurface(
              borderRadius: BorderRadius.circular(LiquidGlassNavBar.height),
              // Plain glass, like the tab pill — no brand tint.
              child: Icon(
                widget.icon,
                color: Theme.of(context).colorScheme.onSurface,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<double> _saturationMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final inv = 1 - s;
  return [
    inv * r + s, inv * g, inv * b, 0, 0, //
    inv * r, inv * g + s, inv * b, 0, 0, //
    inv * r, inv * g, inv * b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
