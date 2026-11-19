import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerts_view.dart';
import 'garden_dashboard.dart';
import 'history_view.dart';
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
  Timer? freshnessTimer;
  bool refreshing = false;
  List<Reading> readings = [];
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
    setState(() {
      readings = items;
      loadError = false;
    });
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
    freshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = readings.isEmpty ? null : readings.first;
    final link = loadError
        ? LinkState.offline
        : realtimeConnected
        ? LinkState.live
        : LinkState.reconnecting;
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          GardenDashboard(reading: latest, link: link, refreshing: refreshing, onRefresh: _refresh),
          HistoryView(readings: readings, onRefresh: _refresh),
          AlertsView(latest: latest),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _alertCount(latest) > 0,
              label: Text('${_alertCount(latest)}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alertas',
          ),
        ],
      ),
    );
  }

  static int _alertCount(Reading? r) {
    if (r == null) return 1;
    return [r.stale, r.tankLow, !r.soilWet, r.distance == null].where((x) => x).length;
  }
}
