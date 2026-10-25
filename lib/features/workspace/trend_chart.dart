import 'package:flutter/material.dart';

class TrendPoint {
  const TrendPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

/// A small, offline trend with gaps for missing dates and an accessible data list.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    required this.source,
  });
  final String title, unit, source;
  final List<TrendPoint> points;
  @override
  Widget build(BuildContext context) {
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final visible = sorted.length > 60
        ? sorted.sublist(sorted.length - 60)
        : sorted;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '$source · $unit · gaps mean not recorded',
            style: theme.textTheme.bodySmall,
          ),
          if (visible.isNotEmpty)
            Semantics(
              label: '$title trend. Values are listed below.',
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _TrendPainter(
                    visible,
                    theme.colorScheme.onSurfaceVariant,
                    theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final point in visible)
                Text(
                  '${point.date.toIso8601String().substring(0, 10)}: ${point.value.toStringAsFixed(1)} $unit',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.stroke, this.grid);
  final List<TrendPoint> points;
  final Color stroke, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final min = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final max = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final duration = points.last.date
        .difference(points.first.date)
        .inMilliseconds;
    final range = max - min;
    final paint = Paint()
      ..color = stroke
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final base = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 16),
      Offset(size.width, size.height - 16),
      base,
    );
    Offset position(TrendPoint p) => Offset(
      duration == 0
          ? size.width / 2
          : (p.date.difference(points.first.date).inMilliseconds / duration) *
                    (size.width - 16) +
                8,
      range == 0
          ? size.height / 2
          : size.height - 24 - (p.value - min) / range * (size.height - 40),
    );
    for (var i = 0; i < points.length; i++) {
      final here = position(points[i]);
      if (i > 0 && points[i].date.difference(points[i - 1].date).inHours <= 36)
        canvas.drawLine(position(points[i - 1]), here, paint);
      canvas.drawCircle(here, 4, Paint()..color = stroke);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.stroke != stroke || old.grid != grid;
}
