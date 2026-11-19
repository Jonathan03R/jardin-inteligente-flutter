import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'garden_dashboard.dart';
import 'reading.dart';

/// Tendencias de las ultimas lecturas (graficas pequenas) y la lista cronologica.
class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.readings, required this.onRefresh});
  final List<Reading> readings;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart_rounded,
        title: 'Aún no hay lecturas',
        text: 'Cuando el ESP32 envíe datos verás aquí las tendencias.',
        action: TextButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
      );
    }
    final ordered = readings.reversed.toList(); // antiguas -> recientes
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PageTitle('Historial', subtitle: 'Últimas lecturas recibidas'),
          _Trend(
            label: 'Humedad de la tierra',
            unit: '%',
            color: AppColors.soil,
            values: [for (final r in ordered) r.soilPercent.toDouble()],
          ),
          _Trend(
            label: 'Temperatura',
            unit: '°C',
            color: AppColors.heat,
            decimals: 1,
            values: [for (final r in ordered) r.temperature],
          ),
          _Trend(
            label: 'Humedad del aire',
            unit: '%',
            color: AppColors.air,
            values: [for (final r in ordered) r.humidity],
          ),
          _Trend(
            label: 'Luz',
            unit: '%',
            color: AppColors.sun,
            values: [for (final r in ordered) r.lightPercent.toDouble()],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 4),
            child: Text('Lecturas', style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          for (final r in readings) ...[
            _ReadingLine(reading: r),
            const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18, color: AppColors.line),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.label, required this.unit, required this.color, required this.values, this.decimals = 0});
  final String label, unit;
  final Color color;
  final List<double?> values;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final data = values.whereType<double>().toList();
    String f(double v) => '${v.toStringAsFixed(decimals)} $unit';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (data.isNotEmpty) ...[
                Text(
                  'mín ${f(data.reduce(min))} · máx ${f(data.reduce(max))}   ',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
                Text(f(data.last), style: const TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w800)),
              ] else
                const Text('Sin dato', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: CustomPaint(painter: _Spark(values, color)),
          ),
        ],
      ),
    );
  }
}

class _Spark extends CustomPainter {
  _Spark(this.values, this.color);
  final List<double?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final data = values.whereType<double>().toList();
    if (data.length < 2) return;
    var lo = data.reduce(min), hi = data.reduce(max);
    if (hi - lo < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      pts.add(Offset(size.width * i / (values.length - 1), size.height * (1 - (v - lo) / (hi - lo))));
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(pts.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _Spark old) => old.values != values || old.color != color;
}

class _ReadingLine extends StatelessWidget {
  const _ReadingLine({required this.reading});
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final t = r.temperature == null ? '—' : '${r.temperature!.toStringAsFixed(1)} °C';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(hhmm(r.recordedAt), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(
              'Tierra ${r.soilWet ? 'húmeda' : 'seca'} · $t${r.raining ? ' · lluvia' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.ink, fontSize: 13.5),
            ),
          ),
          Text(ago(r.recordedAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.ink, fontSize: 26, fontWeight: FontWeight.w800)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title, text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.brand.withValues(alpha: .7)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    ),
  );
}
