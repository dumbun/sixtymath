import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// True when the window is wide and short enough to put two panes side by
/// side (a tablet, a phone on its side, a resized desktop window). Decided
/// from the space we are given, never from the device type.
bool isWideLandscape(BoxConstraints c) =>
    c.maxWidth >= 640 && c.maxWidth > c.maxHeight * 1.2;

/// Graph-paper background with a centred column. The builder is told whether
/// the window is [isWideLandscape] so a screen can pick its layout.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.builder,
    this.narrowMaxWidth = 460,
    this.wideMaxWidth = 920,
  });

  final Widget Function(BuildContext context, bool wide) builder;
  final double narrowMaxWidth;
  final double wideMaxWidth;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Scaffold(
      backgroundColor: t.paper,
      body: CustomPaint(
        painter: _GridPainter(t.grid),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final bool wide = isWideLandscape(box);
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? wideMaxWidth : narrowMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: builder(context, wide),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

/// A bordered box with a hard, un-blurred offset shadow.
class HardBox extends StatelessWidget {
  const HardBox({
    super.key,
    required this.child,
    this.color,
    this.radius = 8,
    this.shadow = Offset.zero,
    this.borderWidth = 2,
    this.padding = EdgeInsets.zero,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final Offset shadow;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.key,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        border: Border.all(color: t.edge, width: borderWidth),
        boxShadow: shadow == Offset.zero
            ? null
            : <BoxShadow>[BoxShadow(color: t.edge, offset: shadow)],
      ),
      child: child,
    );
  }
}

/// A [HardBox] that sinks into its shadow when pressed.
class PressBox extends StatefulWidget {
  const PressBox({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.radius = 8,
    this.shadow = const Offset(0, 4),
    this.padding = EdgeInsets.zero,
    this.fireOnDown = false,
    this.semanticLabel,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final VoidCallback onPressed;
  final Color? color;
  final double radius;
  final Offset shadow;
  final EdgeInsetsGeometry padding;

  /// Fire on touch-down instead of release. Used by the numpad so a fast
  /// player never loses a tap.
  final bool fireOnDown;
  final String? semanticLabel;
  final BoxShape shape;

  @override
  State<PressBox> createState() => _PressBoxState();
}

class _PressBoxState extends State<PressBox> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _set(true);
          if (widget.fireOnDown) widget.onPressed();
        },
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.fireOnDown ? null : widget.onPressed,
        child: Transform.translate(
          offset: _down ? widget.shadow : Offset.zero,
          child: HardBox(
            color: widget.color,
            radius: widget.radius,
            shadow: _down ? Offset.zero : widget.shadow,
            padding: widget.padding,
            shape: widget.shape,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar with a border.
class MeterBar extends StatelessWidget {
  const MeterBar({super.key, required this.value, this.color, this.height = 12});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final double v = value < 0 ? 0 : (value > 1 ? 1 : value);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.key,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.edge, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: ColoredBox(color: color ?? t.pen),
          ),
        ),
      ),
    );
  }
}

/// A row of equal stat cells with a rule above and below.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: t.edge, width: 2),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: t.line),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        items[i].$1.toUpperCase(),
                        style: t.label(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(items[i].$2, style: t.mono(22)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
