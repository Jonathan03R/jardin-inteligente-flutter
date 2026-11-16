class Reading {
  factory Reading.fromDatabase(Map<String, dynamic> row) => Reading.fromJson({
    'id': row['lectura_id'],
    'recorded_at': row['lectura_recibida_en'],
    'soil_raw': row['lectura_suelo'],
    'rain_raw': row['lectura_lluvia'],
    'light_raw': row['lectura_luz'],
    'temperature_c': row['lectura_temperatura'],
    'air_humidity': row['lectura_humedad'],
    'distance_cm': row['lectura_distancia'],
    'soil_wet': row['lectura_suelo_humedo'],
    'raining': row['lectura_lloviendo'],
    'tank_low': row['lectura_tanque_bajo'],
    'dark': row['lectura_oscuro'],
  });
  Reading.fromJson(Map<String, dynamic> row)
    : id = (row['id'] as num).toInt(),
      recordedAt = DateTime.parse(row['recorded_at'] as String).toLocal(),
      soil = row['soil_raw'] as int,
      rain = row['rain_raw'] as int,
      light = row['light_raw'] as int,
      temperature = (row['temperature_c'] as num?)?.toDouble(),
      humidity = (row['air_humidity'] as num?)?.toDouble(),
      distance = (row['distance_cm'] as num?)?.toDouble(),
      soilWet = row['soil_wet'] as bool,
      raining = row['raining'] as bool,
      tankLow = row['tank_low'] as bool,
      dark = row['dark'] as bool;

  final int id, soil, rain, light;
  final DateTime recordedAt;
  final double? temperature, humidity, distance;
  final bool soilWet, raining, tankLow, dark;

  bool get near => distance != null && distance! < 15;
  String get ambientState => raining
      ? 'rain'
      : !soilWet || tankLow
      ? 'thirsty'
      : dark
      ? 'sleep'
      : 'idle';
  bool get stale =>
      DateTime.now().difference(recordedAt) > const Duration(minutes: 1);
}
