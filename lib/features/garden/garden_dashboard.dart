import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../mascot/mascot_brain.dart';
import '../mascot/mascot_stage.dart';
import 'reading.dart';

enum LinkState { live, reconnecting, offline, demo }

/// Pantalla principal: escenario con la mascota y lista compacta de sensores.
class GardenDashboard extends StatelessWidget {
  const GardenDashboard({
    super.key,
    required this.reading,
    required this.link,
    this.refreshing = false,
    this.onRefresh,
    this.brain,
  });

  final Reading? reading;
  final LinkState link;
  final bool refreshing;
  final Future<void> Function()? onRefresh;
  final MascotBrain? brain;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final list = ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        MascotStage(
          reading: r,
          brain: brain,
          header: _Header(link: link, reading: r, refreshing: refreshing, onRefresh: onRefresh),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Row(
            children: [
              const Text(
                'Sensores',
                style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                r == null ? 'Sin lecturas' : 'Lectura de las ${hhmm(r.recordedAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        ..._rows(r),
        const SizedBox(height: 18),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }

  List<Widget> _rows(Reading? r) {
    final rows = <Widget>[
      SensorRow(
        icon: Icons.grass_rounded,
        color: AppColors.soil,
        label: 'Tierra',
        status: r == null ? '—' : r.soilWet ? 'Húmeda' : 'Seca, necesita riego',
        level: r == null ? null : r.soilWet ? Level.ok : Level.bad,
        value: r == null ? '' : '${r.soilPercent} %',
        fraction: r == null ? null : r.soilPercent / 100,
      ),
      SensorRow(
        icon: Icons.water_outlined,
        color: AppColors.water,
        label: 'Tanque',
        status: r == null
            ? '—'
            : r.distance == null
            ? 'Sensor sin eco'
            : r.tankLow
            ? 'Nivel bajo'
            : 'Suficiente',
        level: r == null ? null : r.distance == null ? Level.warn : r.tankLow ? Level.bad : Level.ok,
        value: r?.distance == null ? '' : 'a ${r!.distance!.toStringAsFixed(0)} cm',
      ),
      SensorRow(
        icon: Icons.umbrella_outlined,
        color: AppColors.rain,
        label: 'Lluvia',
        status: r == null ? '—' : r.raining ? 'Está lloviendo' : 'Sin lluvia',
        level: r == null ? null : Level.ok,
        value: r == null ? '' : '${r.rainPercent} %',
        fraction: r == null ? null : r.rainPercent / 100,
      ),
      SensorRow(
        icon: Icons.light_mode_outlined,
        color: AppColors.sun,
        label: 'Luz',
        status: r == null ? '—' : r.dark ? 'Poca luz' : 'Hay luz',
        level: r == null ? null : Level.ok,
        value: r == null ? '' : '${r.lightPercent} %',
        fraction: r == null ? null : r.lightPercent / 100,
      ),
      SensorRow(
        icon: Icons.thermostat_outlined,
        color: AppColors.heat,
        label: 'Temperatura',
        status: _tempStatus(r?.temperature),
        level: _tempLevel(r?.temperature),
        value: r?.temperature == null ? '' : '${r!.temperature!.toStringAsFixed(1)} °C',
      ),
      SensorRow(
        icon: Icons.water_drop_outlined,
        color: AppColors.air,
        label: 'Humedad del aire',
        status: r?.humidity == null ? 'Sin dato' : r!.humidity! < 30 ? 'Aire seco' : r.humidity! > 85 ? 'Muy húmedo' : 'Normal',
        level: r?.humidity == null ? null : Level.ok,
        value: r?.humidity == null ? '' : '${r!.humidity!.toStringAsFixed(0)} %',
        fraction: r?.humidity == null ? null : r!.humidity! / 100,
      ),
    ];
    return [
      for (var i = 0; i < rows.length; i++) ...[
        rows[i],
        if (i < rows.length - 1) const Divider(height: 1, thickness: 1, indent: 56, endIndent: 18, color: AppColors.line),
      ],
    ];
  }

  static String _tempStatus(double? t) => t == null
      ? 'Sin dato'
      : t >= MascotBrain.hotC
      ? 'Mucho calor'
      : t <= MascotBrain.coldC
      ? 'Frío'
      : 'Agradable';

  static Level? _tempLevel(double? t) =>
      t == null ? null : t >= MascotBrain.hotC || t <= MascotBrain.coldC ? Level.warn : Level.ok;
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'hace ${d.inSeconds.clamp(1, 59)} s';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

enum Level { ok, warn, bad }

extension LevelColor on Level {
  Color get color => switch (this) {
    Level.ok => AppColors.ink,
    Level.warn => AppColors.warn,
    Level.bad => AppColors.bad,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.link, required this.reading, required this.refreshing, this.onRefresh});
  final LinkState link;
  final Reading? reading;
  final bool refreshing;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final fg = DefaultTextStyle.of(context).style.color ?? AppColors.ink;
    final (dot, text) = switch (link) {
      LinkState.demo => (AppColors.warn, 'Demo'),
      LinkState.offline => (AppColors.bad, 'Sin conexión'),
      LinkState.reconnecting => (AppColors.warn, 'Reconectando…'),
      LinkState.live =>
        reading == null
            ? (AppColors.warn, 'Sin lecturas')
            : reading!.stale
            ? (AppColors.warn, 'Última ${ago(reading!.recordedAt)}')
            : (AppColors.ok, 'En vivo · ${ago(reading!.recordedAt)}'),
    };
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 6, 0),
        child: Row(
          children: [
            const Text('Mi jardín', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg.withValues(alpha: .8)),
              ),
            ),
            const Spacer(),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Actualizar lecturas',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                    : const Icon(Icons.refresh_rounded, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila de sensor: icono, nombre y estado a la izquierda; valor y medidor a la derecha.
class SensorRow extends StatelessWidget {
  const SensorRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.status,
    required this.value,
    this.level,
    this.fraction,
  });

  final IconData icon;
  final Color color;
  final String label, status, value;
  final Level? level;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final alert = level == Level.warn || level == Level.bad;
    return Semantics(
      label: '$label: $status${value.isEmpty ? '' : ', $value'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      if (alert) ...[
                        Icon(Icons.error_rounded, size: 15, color: level!.color),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: level?.color ?? AppColors.ink,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (fraction != null) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 64,
                      height: 5,
                      child: LinearProgressIndicator(
                        value: fraction!.clamp(0.0, 1.0),
                        backgroundColor: color.withValues(alpha: .15),
                        valueColor: AlwaysStoppedAnimation(alert ? level!.color : color),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
