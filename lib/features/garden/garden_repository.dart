import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'reading.dart';

/// Una consulta inicial, cambios por WebSocket y recuperacion al reconectar.
class GardenRepository {
  GardenRepository(this.client);
  final SupabaseClient client;
  final _changes = StreamController<List<Reading>>.broadcast();
  final _cache = <int, Reading>{};
  RealtimeChannel? _channel;
  int? _device;
  bool _disposed = false;
  Future<void>? _loading;
  void Function(bool)? _connection;
  Stream<List<Reading>> get changes => _changes.stream;

  Future<void> start(String code, void Function(bool) onConnection) async {
    _connection = onConnection;
    if (_channel != null) {
      await refresh();
      return;
    }
    final row = await client
        .from('jardin_dispositivos')
        .select('dispositivo_id')
        .eq('dispositivo_codigo', code)
        .single();
    if (_disposed) return;
    _device = (row['dispositivo_id'] as num).toInt();
    _channel = client
        .channel('jardin-$_device')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'jardin',
          table: 'lecturas',
          filters: [
            PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'dispositivo_id',
              value: _device,
            ),
          ],
          callback: (payload) {
            if (_disposed || payload.newRecord.isEmpty) return;
            try {
              final reading = Reading.fromDatabase(payload.newRecord);
              if (payload.newRecord['activo'] == false) {
                _cache.remove(reading.id);
              } else {
                _cache[reading.id] = reading;
              }
              _emit();
            } catch (error, stack) {
              _changes.addError(error, stack);
            }
          },
        )
        .onSystemEvents((payload) {
          if (_disposed) return;
          if (payload is Map && payload['status'] == 'ok') {
            _connection?.call(true);
            unawaited(
              refresh().catchError((Object error, StackTrace stack) {
                if (!_disposed) _changes.addError(error, stack);
              }),
            );
          }
        })
        .subscribe((status, error) {
          if (_disposed) return;
          _connection?.call(status == RealtimeSubscribeStatus.subscribed);
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(
              refresh().catchError((Object error, StackTrace stack) {
                if (!_disposed) _changes.addError(error, stack);
              }),
            );
          }
        });
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed || _device == null) return;
    // Una segunda consulta tras el join cubre la ventana consulta/suscripcion.
    if (_loading != null) await _loading;
    if (_disposed) return;
    final pending = _fetch();
    _loading = pending;
    try {
      await pending;
    } finally {
      if (identical(_loading, pending)) _loading = null;
    }
  }

  Future<void> _fetch() async {
    final before = Map<int, Reading>.from(_cache);
    final rows = await client
        .from('jardin_lecturas')
        .select()
        .eq('dispositivo_id', _device!)
        .order('lectura_recibida_en', ascending: false)
        .order('lectura_id', ascending: false)
        .limit(60);
    if (_disposed) return;
    for (final row in rows) {
      final reading = Reading.fromDatabase(row);
      // No pisar un evento recibido mientras viajaba la consulta.
      if (identical(_cache[reading.id], before[reading.id])) {
        _cache[reading.id] = reading;
      }
    }
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    final items = _cache.values.toList()
      ..sort((a, b) {
        final date = b.recordedAt.compareTo(a.recordedAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    final recent = items.take(60).toList();
    _cache
      ..clear()
      ..addEntries(recent.map((r) => MapEntry(r.id, r)));
    _changes.add(recent);
  }

  Future<void> dispose() async {
    _disposed = true;
    _connection = null;
    if (_channel != null) await client.removeChannel(_channel!);
    await _changes.close();
  }
}
