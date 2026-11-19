import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jardin_inteligente/features/garden/reading.dart';
import 'package:jardin_inteligente/features/mascot/mascot_brain.dart';

Reading reading(
  int id, {
  bool wet = true,
  bool rain = false,
  bool dark = false,
  bool tankLow = false,
  double temp = 24,
  double distance = 30,
}) => Reading.fromJson({
  'id': id,
  'recorded_at': DateTime.now().toUtc().toIso8601String(),
  'soil_raw': wet ? 1400 : 3200,
  'rain_raw': rain ? 900 : 3400,
  'light_raw': dark ? 400 : 2900,
  'temperature_c': temp,
  'air_humidity': 60,
  'distance_cm': distance,
  'soil_wet': wet,
  'raining': rain,
  'tank_low': tankLow,
  'dark': dark,
});

void main() {
  late DateTime now;
  late MascotBrain brain;
  late List<Reaction> reactions;

  setUp(() {
    now = DateTime(2026, 11, 18, 12);
    brain = MascotBrain(random: Random(1), clock: () => now);
    reactions = [];
    brain.onReact = reactions.add;
  });

  void later(int seconds) => now = now.add(Duration(seconds: seconds));

  test('el animo sale de los sensores con prioridad lluvia > sed > sueno > temperatura', () {
    brain.update(reading(1, rain: true, wet: false));
    expect(brain.mood, Mood.rainy);
    brain.update(reading(2, wet: false, dark: true));
    expect(brain.mood, Mood.thirsty);
    brain.update(reading(3, dark: true));
    expect(brain.mood, Mood.sleepy);
    brain.update(reading(4, temp: 35));
    expect(brain.mood, Mood.hot);
    brain.update(reading(5, temp: 8));
    expect(brain.mood, Mood.cold);
    brain.update(reading(6));
    expect(brain.mood, Mood.content);
    brain.update(null);
    expect(brain.mood, Mood.waiting);
  });

  test('saluda con la primera lectura y agradece el riego', () {
    brain.update(reading(1, wet: false));
    expect(reactions, [Reaction.wave]);
    later(5);
    brain.update(reading(2, wet: true));
    expect(reactions.last, Reaction.refresh);
    expect(brain.thought, contains('agua'));
    expect(brain.joy, greaterThan(0.6));
  });

  test('no encadena reacciones mientras otra se reproduce', () {
    brain.update(reading(1));
    brain.update(reading(2, distance: 5)); // se acerca alguien, pero aun saluda
    expect(reactions, [Reaction.wave]);
  });

  test('tiene ideas propias cuando se aburre, y no despierta sola de noche', () {
    brain.update(reading(1));
    reactions.clear();
    for (var i = 0; i < 40; i++) {
      later(1);
      brain.tick();
    }
    expect(reactions, isNotEmpty);

    brain.update(reading(2, dark: true));
    reactions.clear();
    for (var i = 0; i < 60; i++) {
      later(1);
      brain.tick();
    }
    expect(reactions, isEmpty);
  });

  test('tres toques seguidos la ponen a bailar; dormida se sobresalta', () {
    brain.update(reading(1));
    later(3);
    brain.poke();
    brain.poke();
    brain.poke();
    expect(reactions.last, Reaction.dance);
    brain.update(reading(2, dark: true));
    later(5);
    brain.poke();
    expect(reactions.last, Reaction.surprise);
  });
}
