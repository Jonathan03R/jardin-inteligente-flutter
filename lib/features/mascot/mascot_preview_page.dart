import 'dart:async';

import 'package:flutter/material.dart';

import '../garden/garden_dashboard.dart';
import '../garden/reading.dart';

/// Simulacion automatica de sensores para revisar la app sin hardware (`--dart-define=DEMO_MODE=true`).
/// Recorre todos los animos; al pasar de "seco" a "humedo" la mascota agradece el riego.
class MascotPreviewPage extends StatefulWidget {
  const MascotPreviewPage({super.key});

  @override
  State<MascotPreviewPage> createState() => _MascotPreviewPageState();
}

class _MascotPreviewPageState extends State<MascotPreviewPage> {
  static const steps = ['content', 'rain', 'thirsty', 'content', 'hot', 'cold', 'sleep', 'near'];
  Timer? timer;
  int index = 0;
  int id = 1;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        setState(() {
          index = (index + 1) % steps.length;
          id++;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Reading get sample {
    final s = steps[index];
    return Reading.fromJson({
      'id': id,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'soil_raw': s == 'thirsty' ? 3150 : 1430,
      'rain_raw': s == 'rain' ? 900 : 3450,
      'light_raw': s == 'sleep' ? 420 : 2900,
      'temperature_c': switch (s) {
        'rain' => 19.4,
        'hot' => 34.2,
        'cold' => 9.5,
        _ => 24.6,
      },
      'air_humidity': s == 'rain' ? 88.0 : 61.0,
      'distance_cm': s == 'near' ? 9.0 : 24.0,
      'soil_wet': s != 'thirsty',
      'raining': s == 'rain',
      'tank_low': false,
      'dark': s == 'sleep',
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GardenDashboard(reading: sample, link: LinkState.demo),
  );
}
