import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'garden_dashboard.dart';
import 'garden_repository.dart';
import 'reading.dart';

class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> with WidgetsBindingObserver {
  static const deviceId = 'garden-01';
  late final GardenRepository repository = GardenRepository(
    Supabase.instance.client,
  );
  StreamSubscription<List<Reading>>? subscription;
  bool realtimeConnected = false;
  bool started = false;
  Timer? happyTimer;
  Timer? freshnessTimer;
  bool refreshing = false;
  List<Reading> readings = [];
  bool wasNear = false;
  String? temporaryState;
  bool loadError = false;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = repository.changes.listen(
      _accept,
      onError: (Object error) {
        if (mounted) setState(() => loadError = true);
      },
    );
    freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  void _accept(List<Reading> items) {
    if (!mounted) return;
    final near = items.isNotEmpty && items.first.near;
    final fresh = items.isNotEmpty && !items.first.stale;
    final greeting = near && !wasNear && fresh && readings.isNotEmpty;
    setState(() {
      readings = items;
      wasNear = near;
      loadError = false;
      if (greeting) temporaryState = 'happy';
    });
    if (greeting) {
      happyTimer?.cancel();
      happyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => temporaryState = null);
      });
    }
  }

  Future<void> _refresh() async {
    if (refreshing) return;
    refreshing = true;
    if (mounted) setState(() {});
    try {
      if (!started) {
        await repository.start(deviceId, (connected) {
          if (mounted) setState(() => realtimeConnected = connected);
        });
        started = true;
      } else {
        await repository.refresh();
      }
    } catch (_) {
      if (mounted) setState(() => loadError = true);
    } finally {
      refreshing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(subscription?.cancel());
    unawaited(repository.dispose());
    happyTimer?.cancel();
    freshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = readings.isEmpty ? null : readings.first;
    final state = temporaryState ?? latest?.ambientState ?? 'idle';
    return Scaffold(
      appBar: AppBar(
        title: Text(['Resumen', 'Historial', 'Alertas'][tab]),
        actions: [
          IconButton(
            tooltip: 'Actualizar lecturas',
            onPressed: refreshing ? null : _refresh,
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!realtimeConnected && !loadError)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Reconectando actualizaciones en vivo…'),
              ),
            if (loadError)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.wifi_off, color: Colors.redAccent),
                    title: Text('Sin conexión con Supabase'),
                    subtitle: Text(
                      'Comprueba Internet y la configuración del proyecto.',
                    ),
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  GardenDashboard(
                    deviceName: 'Mi jardín',
                    state: state,
                    reading: latest,
                  ),
                  _history(),
                  _alerts(latest),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Alertas',
          ),
        ],
      ),
    );
  }

  Widget _history() {
    if (readings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aún no hay lecturas en Supabase.'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: readings.length,
      itemBuilder: (context, index) {
        final reading = readings[index];
        return ListTile(
          leading: Icon(reading.raining ? Icons.cloudy_snowing : Icons.spa),
          title: Text(
            'Tierra ${reading.soilWet ? 'húmeda' : 'seca'} · ${reading.temperature?.toStringAsFixed(1) ?? '—'} °C',
          ),
          subtitle: Text(
            '${reading.recordedAt.toString().substring(0, 19)} · Lluvia ${reading.raining ? 'sí' : 'no'}',
          ),
        );
      },
    );
  }

  Widget _alerts(Reading? latest) {
    final messages = <String>[
      if (latest == null || latest.stale) 'Sin lecturas recientes en Supabase',
      if (latest?.tankLow ?? false) 'Agua baja en el tanque',
      if (latest != null && !latest.soilWet) 'Tierra seca: revisa el riego',
      if (latest?.raining ?? false) 'Está lloviendo',
      if (latest != null && latest.distance == null) 'Sensor de tanque sin eco',
    ];
    if (messages.isEmpty) messages.add('Todo bien en el jardín');
    return ListView(
      children: [
        for (final message in messages)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(message),
          ),
      ],
    );
  }
}
