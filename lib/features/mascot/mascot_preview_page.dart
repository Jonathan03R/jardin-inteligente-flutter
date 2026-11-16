import 'dart:async';

import 'package:flutter/material.dart';

import '../garden/garden_dashboard.dart';
import '../garden/reading.dart';

/// Automatic sensor simulation for inspecting the app without hardware.
class MascotPreviewPage extends StatefulWidget {
  const MascotPreviewPage({super.key});

  @override
  State<MascotPreviewPage> createState() => _MascotPreviewPageState();
}

class _MascotPreviewPageState extends State<MascotPreviewPage> {
  static const states = ['idle', 'rain', 'thirsty', 'sleep', 'happy'];
  Timer? timer;
  int index = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => index = (index + 1) % states.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Reading get sample {
    final state = states[index];
    return Reading.fromJson({
      'id': index + 1,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'soil_raw': state == 'thirsty' ? 3050 : 1430,
      'rain_raw': state == 'rain' ? 900 : 3450,
      'light_raw': state == 'sleep' ? 500 : 2900,
      'temperature_c': state == 'rain' ? 21.4 : 24.6,
      'air_humidity': state == 'rain' ? 83.0 : 62.0,
      'distance_cm': state == 'thirsty' ? 29.0 : 10.2,
      'soil_wet': state != 'thirsty',
      'raining': state == 'rain',
      'tank_low': state == 'thirsty',
      'dark': state == 'sleep',
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8F2),
    body: SafeArea(
      child: GardenDashboard(
        deviceName: 'Mi jardín',
        state: states[index],
        reading: sample,
        demo: true,
      ),
    ),
  );
}
