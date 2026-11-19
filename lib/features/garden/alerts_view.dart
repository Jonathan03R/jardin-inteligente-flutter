import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../mascot/mascot_brain.dart';
import 'garden_dashboard.dart';
import 'history_view.dart';
import 'reading.dart';

class _Alert {
  const _Alert(this.icon, this.level, this.title, this.hint);
  final IconData icon;
  final Level level;
  final String title, hint;
}

/// Condiciones de la lectura actual, ordenadas por gravedad.
class AlertsView extends StatelessWidget {
  const AlertsView({super.key, required this.latest});
  final Reading? latest;

  @override
  Widget build(BuildContext context) {
    final r = latest;
    final alerts = <_Alert>[
      if (r == null)
        const _Alert(Icons.cloud_off_rounded, Level.warn, 'Sin lecturas', 'Revisa que el ESP32 y la laptop estén encendidos.')
      else if (r.stale)
        _Alert(Icons.schedule_rounded, Level.warn, 'Lectura antigua', 'La última llegó ${ago(r.recordedAt)}.'),
      if (r != null && r.tankLow)
        const _Alert(Icons.water_outlined, Level.bad, 'Agua baja en el tanque', 'Rellena el tanque para poder regar.'),
      if (r != null && !r.soilWet)
        _Alert(Icons.grass_rounded, Level.bad, 'Tierra seca', 'Humedad ${r.soilPercent} %. Conviene regar.'),
      if (r != null && r.distance == null)
        const _Alert(Icons.sensors_off_rounded, Level.warn, 'Sensor de tanque sin eco', 'Revisa la conexión del sensor ultrasónico.'),
      if (r?.temperature != null && r!.temperature! >= MascotBrain.hotC)
        _Alert(Icons.thermostat_rounded, Level.warn, 'Mucho calor', '${r.temperature!.toStringAsFixed(1)} °C. Evita regar al mediodía.'),
      if (r?.temperature != null && r!.temperature! <= MascotBrain.coldC)
        _Alert(Icons.ac_unit_rounded, Level.warn, 'Hace frío', '${r.temperature!.toStringAsFixed(1)} °C para tus plantas.'),
      if (r != null && r.raining)
        const _Alert(Icons.umbrella_outlined, Level.ok, 'Está lloviendo', 'No hace falta regar por ahora.'),
    ]..sort((a, b) => b.level.index.compareTo(a.level.index));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageTitle('Alertas', subtitle: alerts.isEmpty ? 'Estado de la lectura actual' : '${alerts.length} en la lectura actual'),
        if (alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Todo bien en el jardín',
              text: 'No hay nada que atender ahora mismo.',
            ),
          ),
        for (final a in alerts) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: a.level == Level.ok ? AppColors.rain : a.level.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(a.icon, size: 22, color: a.level == Level.ok ? AppColors.rain : a.level.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(color: AppColors.ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(a.hint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18, color: AppColors.line),
        ],
      ],
    );
  }
}
