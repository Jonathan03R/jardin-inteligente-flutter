import 'package:flutter/material.dart';

import '../mascot/mascot_card.dart';
import 'reading.dart';

class GardenDashboard extends StatelessWidget {
  const GardenDashboard({
    super.key,
    required this.deviceName,
    required this.state,
    required this.reading,
    this.demo = false,
  });

  final String deviceName;
  final String state;
  final Reading? reading;
  final bool demo;

  static const ink = Color(0xFF1A3027);
  static const muted = Color(0xFF64766B);

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final live = r != null && !r.stale;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MI JARDÍN',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: demo
                    ? const Color(0xFFFFEFCB)
                    : live
                    ? const Color(0xFFDDEFE0)
                    : const Color(0xFFF1E4D9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    demo
                        ? Icons.science_outlined
                        : live
                        ? Icons.circle
                        : r == null
                        ? Icons.inbox_outlined
                        : Icons.wifi_off,
                    size: 13,
                    color: demo
                        ? const Color(0xFF8B5B19)
                        : live
                        ? const Color(0xFF288452)
                        : const Color(0xFF9B5B41),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    demo
                        ? 'Demo'
                        : live
                        ? 'En vivo'
                        : r == null
                        ? 'Sin lecturas'
                        : 'Sin señal',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        MascotCard(state: state),
        const SizedBox(height: 16),
        if (demo || !live)
          _Notice(
            text: demo
                ? 'Demostración automática. Valores simulados, sin conexión al ESP32.'
                : r == null
                ? 'Aún no hay lecturas en Supabase.'
                : 'La última lectura en Supabase es antigua.',
            icon: demo || r == null
                ? Icons.info_outline
                : Icons.wifi_off_outlined,
          ),
        const SizedBox(height: 22),
        const Text(
          'Así está tu jardín',
          style: TextStyle(
            color: ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          r == null
              ? 'Los sensores aparecerán aquí.'
              : 'Última lectura: ${_time(r.recordedAt)}',
          style: const TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SensorCard(
                  width: width,
                  icon: Icons.grass_rounded,
                  title: 'Tierra',
                  value: r == null
                      ? '—'
                      : r.soilWet
                      ? 'Húmeda'
                      : 'Seca',
                  detail: r == null ? 'Sin datos' : '${r.soil} / 4095',
                  tone: const Color(0xFF4D8A58),
                ),
                _SensorCard(
                  width: width,
                  icon: Icons.water_drop_outlined,
                  title: 'Lluvia',
                  value: r == null
                      ? '—'
                      : r.raining
                      ? 'Llueve'
                      : 'Sin lluvia',
                  detail: r == null ? 'Sin datos' : '${r.rain} / 4095',
                  tone: const Color(0xFF4A83AB),
                ),
                _SensorCard(
                  width: width,
                  icon: Icons.water_outlined,
                  title: 'Tanque',
                  value: r == null
                      ? '—'
                      : r.distance == null
                      ? 'Sin eco'
                      : r.tankLow
                      ? 'Nivel bajo'
                      : 'Suficiente',
                  detail: _number(r?.distance, 'cm'),
                  tone: const Color(0xFF4D91A3),
                ),
                _SensorCard(
                  width: width,
                  icon: Icons.light_mode_outlined,
                  title: 'Luz',
                  value: r == null
                      ? '—'
                      : r.dark
                      ? 'Poca luz'
                      : 'Hay luz',
                  detail: r == null ? 'Sin datos' : '${r.light} / 4095',
                  tone: const Color(0xFFBE8B37),
                ),
                _SensorCard(
                  width: width,
                  icon: Icons.thermostat_outlined,
                  title: 'Temperatura',
                  value: _number(r?.temperature, '°C'),
                  detail: 'Aire',
                  tone: const Color(0xFFC57856),
                ),
                _SensorCard(
                  width: width,
                  icon: Icons.air_outlined,
                  title: 'Humedad aire',
                  value: _number(r?.humidity, '%'),
                  detail: 'DHT11',
                  tone: const Color(0xFF6887A2),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _number(double? n, String unit) =>
      n == null ? 'Sin dato' : '${n.toStringAsFixed(1)} $unit';
  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1DB),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9A6429)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF5F492E),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.tone,
  });
  final double width;
  final IconData icon;
  final String title, value, detail;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 124),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EEE7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: tone, size: 20),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GardenDashboard.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: GardenDashboard.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: GardenDashboard.muted, fontSize: 11),
        ),
      ],
    ),
  );
}
