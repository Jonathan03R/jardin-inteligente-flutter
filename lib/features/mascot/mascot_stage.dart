import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../garden/reading.dart';
import 'mascot_brain.dart';
import 'mascot_view.dart';

/// Escenario superior: cielo segun el animo, particulas del clima y la mascota 3D.
/// Recibe la lectura de Supabase y la convierte en emociones a traves de [MascotBrain].
class MascotStage extends StatefulWidget {
  const MascotStage({super.key, required this.reading, required this.header, this.brain});
  final Reading? reading;
  final Widget header;

  /// Permite inyectar un cerebro (modo demo / pruebas).
  final MascotBrain? brain;

  @override
  State<MascotStage> createState() => _MascotStageState();
}

class _Sky {
  const _Sky(this.top, this.bottom, this.dark);
  final Color top, bottom;
  final bool dark;
}

const _skies = {
  Mood.content: _Sky(Color(0xFFBFE0A8), Color(0xFFE7F2DA), false),
  Mood.waiting: _Sky(Color(0xFFD5DCCF), Color(0xFFEBEFE6), false),
  Mood.thirsty: _Sky(Color(0xFFF0C98A), Color(0xFFF8E7C6), false),
  Mood.sleepy: _Sky(Color(0xFF1C2747), Color(0xFF3A4A76), true),
  Mood.rainy: _Sky(Color(0xFF8FB4CE), Color(0xFFD3E3EC), false),
  Mood.hot: _Sky(Color(0xFFFFB877), Color(0xFFFFE2BE), false),
  Mood.cold: _Sky(Color(0xFFC3DBF1), Color(0xFFEAF3FB), false),
};

class _MascotStageState extends State<MascotStage> with SingleTickerProviderStateMixin {
  late final MascotBrain brain = widget.brain ?? MascotBrain();
  final controller = MascotController();
  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..repeat();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    brain.onReact = (r) => controller.react(r.clip);
    brain.addListener(_sync);
    _sentStale = widget.reading?.stale;
    brain.update(widget.reading);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => brain.tick());
  }

  @override
  void didUpdateWidget(covariant MascotStage old) {
    super.didUpdateWidget(old);
    // `stale` depende del reloj: comparar con lo ultimo enviado, no con el widget anterior.
    final stale = widget.reading?.stale;
    if (old.reading?.id != widget.reading?.id || stale != _sentStale) {
      _sentStale = stale;
      brain.update(widget.reading);
    }
  }

  bool? _sentStale;

  void _sync() {
    controller
      ..setBase(brain.mood.clip)
      ..leafColor(brain.leafColor);
  }

  @override
  void dispose() {
    _tick?.cancel();
    brain.removeListener(_sync);
    if (widget.brain == null) brain.dispose();
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.46).clamp(330.0, 460.0);
    return ListenableBuilder(
      listenable: brain,
      builder: (context, _) {
        final sky = _skies[brain.mood]!;
        final fg = sky.dark ? Colors.white : const Color(0xFF17291F);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [sky.top, sky.bottom],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _WeatherPainter(brain.mood, clock)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 52,
                bottom: 70,
                child: MascotView(controller: controller, onTap: brain.poke),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: IconTheme.merge(data: IconThemeData(color: fg), child: widget.header)),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    key: ValueKey('${brain.title}|${brain.thought}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        brain.title,
                        style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w800, height: 1.1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        brain.thought,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg.withValues(alpha: .78), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Particulas baratas, dibujadas por Flutter detras del WebView transparente.
class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.mood, this.clock) : super(repaint: clock);
  final Mood mood;
  final Animation<double> clock;

  static final _seeds = List.generate(70, (i) {
    final r = Random(i * 7919);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final p = Paint()..isAntiAlias = true;
    switch (mood) {
      case Mood.rainy:
        p
          ..color = Colors.white.withValues(alpha: .55)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (final (x, y, s) in _seeds) {
          final speed = 5 + s * 3;
          final yy = ((y + t * speed) % 1.0) * (size.height + 40) - 20;
          final xx = (x * (size.width + 60)) - 30 - yy * 0.12;
          canvas.drawLine(Offset(xx, yy), Offset(xx - 3, yy + 12 + s * 6), p);
        }
      case Mood.sleepy:
        _moon(canvas, size);
        for (final (x, y, s) in _seeds.take(40)) {
          final tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(2 * pi * (t * (1 + s * 2) + x)));
          p.color = Colors.white.withValues(alpha: tw * 0.8);
          canvas.drawCircle(Offset(x * size.width, y * size.height * 0.75), 0.8 + s * 1.4, p);
        }
      case Mood.content:
      case Mood.thirsty:
      case Mood.hot:
        final strength = mood == Mood.hot ? 1.0 : mood == Mood.thirsty ? .8 : .55;
        final c = Offset(size.width * .84, size.height * .14);
        final glow = 70 + 8 * sin(2 * pi * t * 3);
        p.shader = RadialGradient(colors: [
          const Color(0xFFFFF4C2).withValues(alpha: .9 * strength),
          const Color(0xFFFFE08A).withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: glow * 2.2));
        canvas.drawCircle(c, glow * 2.2, p);
        p.shader = null;
        // motas de polen (contento) o polvo (sed/calor) que flotan hacia arriba
        p.color = (mood == Mood.content ? Colors.white : const Color(0xFFFFF1D6)).withValues(alpha: .55);
        for (final (x, y, s) in _seeds.take(18)) {
          final yy = size.height - ((y + t * (0.6 + s)) % 1.0) * size.height;
          final xx = x * size.width + 10 * sin(2 * pi * (t * 2 + s));
          canvas.drawCircle(Offset(xx, yy), 1.2 + s * 1.6, p);
        }
        if (mood == Mood.hot) {
          p
            ..color = Colors.white.withValues(alpha: .28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          for (var k = 0; k < 4; k++) {
            final path = Path();
            final y0 = size.height * (0.3 + k * 0.14);
            for (var x = 0.0; x <= size.width; x += 8) {
              final y = y0 + 4 * sin(x / 22 + t * 2 * pi * 4 + k);
              x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
            }
            canvas.drawPath(path, p);
          }
          p.style = PaintingStyle.fill;
        }
      case Mood.cold:
        p.color = Colors.white.withValues(alpha: .85);
        for (final (x, y, s) in _seeds.take(45)) {
          final yy = ((y + t * (1 + s)) % 1.0) * size.height;
          final xx = x * size.width + 14 * sin(2 * pi * (t * 3 + s * 5));
          canvas.drawCircle(Offset(xx, yy), 1.4 + s * 2, p);
        }
      case Mood.waiting:
        break;
    }
  }

  void _moon(Canvas canvas, Size size) {
    final c = Offset(size.width * .82, size.height * .16);
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFDDE6FF).withValues(alpha: .35),
        const Color(0xFFDDE6FF).withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: c, radius: 70));
    canvas.drawCircle(c, 70, glow);
    final moon = Path()
      ..addOval(Rect.fromCircle(center: c, radius: 18))
      ..fillType = PathFillType.evenOdd;
    final bite = Path()..addOval(Rect.fromCircle(center: c + const Offset(8, -6), radius: 16));
    canvas.drawPath(Path.combine(PathOperation.difference, moon, bite), Paint()..color = const Color(0xFFF4F1DC));
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => old.mood != mood;
}
