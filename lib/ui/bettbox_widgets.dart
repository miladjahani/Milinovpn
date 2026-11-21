import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bettbox-style opaque, calm, high-contrast dashboard card with `InfoHeader`,
/// subtle tilted background watermark icon, and tactile press feedback.
class BettboxTileCard extends StatefulWidget {
  final String title;
  final IconData? icon;
  final List<Widget> actions;
  final IconData? watermarkIcon;
  final String? watermarkEmoji;
  final double watermarkAngle;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Widget child;
  final EdgeInsetsGeometry contentPadding;

  const BettboxTileCard({
    super.key,
    required this.title,
    this.icon,
    this.actions = const [],
    this.watermarkIcon,
    this.watermarkEmoji,
    this.watermarkAngle = -0.2,
    this.onTap,
    this.borderColor,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
    required this.child,
  });

  @override
  State<BettboxTileCard> createState() => _BettboxTileCardState();
}

class _BettboxTileCardState extends State<BettboxTileCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    const radiusValue = 24.0;
    final radius = BorderRadius.circular(radiusValue);
    final edge = widget.borderColor ?? scheme.onSurface;
    final edgeAlpha = widget.borderColor != null ? 0.82 : (isLight ? 0.30 : 0.20);
    final base = isLight
        ? Colors.white.withValues(alpha: 0.92)
        : scheme.surfaceContainer.withValues(alpha: 0.76);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                edge.withValues(alpha: edgeAlpha),
                edge.withValues(alpha: 0.025),
              ],
            ),
            boxShadow: [
              if (isLight)
                const BoxShadow(
                  color: Color(0x12000000),
                  offset: Offset(0, 4),
                  blurRadius: 14,
                ),
              if (widget.borderColor != null)
                BoxShadow(
                  color: widget.borderColor!.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radiusValue - 1),
              child: Material(
                color: base,
                child: InkWell(
                  onTap: widget.onTap == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          widget.onTap!();
                        },
                  onHighlightChanged: widget.onTap == null
                      ? null
                      : (highlighted) =>
                            setState(() => _pressed = highlighted),
                  overlayColor: WidgetStatePropertyAll(
                    scheme.primary.withValues(alpha: 0.06),
                  ),
                  child: Stack(
                    children: [
                      // A faint top sheen, like a piece of glass catching the light.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: isLight ? 0.12 : 0.035),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.watermarkIcon != null ||
                          widget.watermarkEmoji != null)
                        PositionedDirectional(
                          end: -10,
                          bottom: -14,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: widget.watermarkAngle,
                              child: widget.watermarkEmoji != null
                                  ? Opacity(
                                      opacity: 0.11,
                                      child: Text(
                                        widget.watermarkEmoji!,
                                        style: const TextStyle(fontSize: 62),
                                      ),
                                    )
                                  : Icon(
                                      widget.watermarkIcon,
                                      size: 74,
                                      color: scheme.onSurface.withValues(alpha: 0.045),
                                    ),
                            ),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 13, 12, 6),
                            child: Row(
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(
                                    widget.icon,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 7),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                ...widget.actions,
                              ],
                            ),
                          ),
                          Padding(
                            padding: widget.contentPadding,
                            child: widget.child,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

/// Bettbox-style opaque interactive pill chip.
class BettboxChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const BettboxChip({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = active
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.surfaceContainerHigh.withValues(alpha: 0.62);
    final fg = active ? scheme.primary : scheme.onSurface;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: active
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.outlineVariant.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smooth cubic-Bezier LineChart with vertical gradient fill & revision-driven repaint
/// (never freezes even when underlying speed lists update every second).
class BettboxLineChart extends StatelessWidget {
  final List<double> values;
  final int revision;
  final Color color;
  final double height;

  const BettboxLineChart({
    super.key,
    required this.values,
    required this.revision,
    required this.color,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BettboxLineChartPainter(
            values: values,
            revision: revision,
            color: color,
            baselineColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _BettboxLineChartPainter extends CustomPainter {
  final List<double> values;
  final int revision;
  final Color color;
  final Color baselineColor;

  const _BettboxLineChartPainter({
    required this.values,
    required this.revision,
    required this.color,
    required this.baselineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle baseline
    canvas.drawLine(
      Offset(0, size.height - 1.5),
      Offset(size.width, size.height - 1.5),
      Paint()
        ..color = baselineColor.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    final pts = values.length < 2 ? const [0.0, 0.0] : values;
    final maxVal = math.max(1024.0, pts.reduce(math.max));
    final stepX = size.width / (pts.length - 1);
    const topPad = 5.0;
    final usableH = size.height - topPad - 2.5;

    final coords = <Offset>[
      for (int i = 0; i < pts.length; i++)
        Offset(
          i * stepX,
          size.height - 2.5 - ((pts[i] / maxVal).clamp(0.0, 1.0)) * usableH,
        ),
    ];

    final path = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (int i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, size.height - 1.5)
      ..lineTo(coords.first.dx, size.height - 1.5)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [color.withValues(alpha: 0.24), color.withValues(alpha: 0.0)],
      );
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_BettboxLineChartPainter oldDelegate) =>
      oldDelegate.revision != revision || oldDelegate.color != color;
}

/// Bettbox-style opaque floating pill bottom navigation bar with spring pill animation.
class BettboxFloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<({IconData icon, String label})> items;

  const BettboxFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final barBg = isLight
        ? Colors.white.withValues(alpha: 0.82)
        : scheme.surfaceContainerHigh.withValues(alpha: 0.76);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.12),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.40),
                    blurRadius: 22,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < items.length; i++)
                    _NavPillItem(
                      icon: items[i].icon,
                      label: items[i].label,
                      selected: i == selectedIndex,
                      onTap: () {
                        if (i != selectedIndex) {
                          HapticFeedback.selectionClick();
                          onChanged(i);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slow, state-aware mesh gradient behind the Bento content. It replaces flat black with
/// three soft light fields (idle, connecting, connected, or error) without animating the cards
/// themselves. RepaintBoundary keeps the per-second dashboard ticker from repainting it.
class BentoBackground extends StatefulWidget {
  final Color accent;
  final bool connected;
  final bool busy;
  final bool failed;

  const BentoBackground({
    super.key,
    required this.accent,
    this.connected = false,
    this.busy = false,
    this.failed = false,
  });

  @override
  State<BentoBackground> createState() => _BentoBackgroundState();
}

class _BentoBackgroundState extends State<BentoBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced-motion settings: the mesh then stays calm instead of burning frames.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final accent = widget.failed
        ? Theme.of(context).colorScheme.error
        : widget.connected
        ? const Color(0xFF34D399)
        : widget.accent;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _BentoMeshPainter(
              phase: reduceMotion ? 0.4 : _controller.value * math.pi * 2,
              accent: accent,
              intensity: widget.busy ? 1.25 : 1.0,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _BentoMeshPainter extends CustomPainter {
  final double phase;
  final Color accent;
  final double intensity;

  const _BentoMeshPainter({
    required this.phase,
    required this.accent,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF070A10), Color(0xFF040507), Color(0xFF080510)],
        ).createShader(rect),
    );

    void blob(Offset center, double radius, Color color, double alpha) {
      final area = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ).createShader(area),
      );
    }

    final w = size.width;
    final h = size.height;
    blob(
      Offset(
        w * (0.18 + 0.08 * math.sin(phase)),
        h * (0.16 + 0.05 * math.cos(phase * 0.8)),
      ),
      w * 0.72,
      accent,
      0.11 * intensity,
    );
    blob(
      Offset(
        w * (0.88 + 0.06 * math.cos(phase * 0.7)),
        h * (0.48 + 0.08 * math.sin(phase * 0.6)),
      ),
      w * 0.60,
      const Color(0xFF8B5CF6),
      0.065 * intensity,
    );
    blob(
      Offset(
        w * (0.28 + 0.09 * math.cos(phase * 0.9)),
        h * (0.92 + 0.04 * math.sin(phase * 0.5)),
      ),
      w * 0.66,
      const Color(0xFF0EA5E9),
      0.045 * intensity,
    );
  }

  @override
  bool shouldRepaint(_BentoMeshPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.accent != accent ||
      oldDelegate.intensity != intensity;
}

class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 15 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected ? scheme.primaryContainer : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 7),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
