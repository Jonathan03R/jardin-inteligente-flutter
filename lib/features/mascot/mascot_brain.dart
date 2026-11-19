import 'dart:math';

import 'package:flutter/foundation.dart';

import '../garden/reading.dart';

/// Estado de animo de base. Cada uno tiene una animacion en bucle en `brotito.glb`.
enum Mood { content, thirsty, sleepy, rainy, hot, cold, waiting }

/// Reacciones de una sola vez. El nombre coincide con la animacion del GLB.
enum Reaction { wave, dance, jump, surprise, curious, yawn, giggle, refresh }

extension ReactionClip on Reaction {
  String get clip => name[0].toUpperCase() + name.substring(1);

  /// Duracion real de cada clip (segundos), para no encadenar reacciones encima.
  double get seconds => const {
    Reaction.wave: 2.0,
    Reaction.dance: 4.0,
    Reaction.jump: 1.5,
    Reaction.surprise: 1.5,
    Reaction.curious: 3.5,
    Reaction.yawn: 3.0,
    Reaction.giggle: 1.5,
    Reaction.refresh: 2.5,
  }[this]!;
}

extension MoodClip on Mood {
  String get clip => const {
    Mood.content: 'Idle',
    Mood.waiting: 'Idle',
    Mood.thirsty: 'Thirsty',
    Mood.sleepy: 'Sleep',
    Mood.rainy: 'Rain',
    Mood.hot: 'Hot',
    Mood.cold: 'Cold',
  }[this]!;
}

/// Personalidad de la mascota.
///
/// El animo de base sale de la ultima lectura de Supabase. Encima, la mascota tiene
/// sentimientos propios que cambian solos: alegria (sube con riego, saludos y caricias,
/// baja con el tiempo), aburrimiento (crece si no pasa nada) y energia (baja de noche).
/// Con ellos decide por si misma cuando curiosear, bostezar, bailar o saludar.
class MascotBrain extends ChangeNotifier {
  MascotBrain({Random? random, DateTime Function()? clock})
    : _random = random ?? Random(),
      _now = clock ?? DateTime.now;

  static const hotC = 32.0;
  static const coldC = 12.0;

  final Random _random;
  final DateTime Function() _now;

  Mood _mood = Mood.waiting;
  Reading? _last;
  bool _lastFresh = false;
  double joy = 0.35;
  double boredom = 0;
  double energy = 1;
  DateTime _busyUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _nextIdea = DateTime.fromMillisecondsSinceEpoch(0);
  final List<DateTime> _pokes = [];
  String? _say;
  DateTime _sayUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Se llama cada vez que la mascota decide reaccionar.
  void Function(Reaction reaction)? onReact;

  Mood get mood => _mood;

  /// Frase actual: un comentario de evento si es reciente, o el pensamiento del animo.
  String get thought =>
      _say != null && _now().isBefore(_sayUntil) ? _say! : _moodThought();

  String get title => const {
    Mood.content: 'Contento',
    Mood.waiting: 'Esperando datos',
    Mood.thirsty: 'Tengo sed',
    Mood.sleepy: 'Durmiendo',
    Mood.rainy: '¡Llueve!',
    Mood.hot: 'Mucho calor',
    Mood.cold: 'Tengo frío',
  }[_mood]!;

  /// Recibe la lectura mas reciente. Detecta cambios y reacciona a ellos.
  void update(Reading? reading) {
    final fresh = reading != null && !reading.stale;
    final previous = _last;
    final next = _moodFor(reading, fresh);
    final now = _now();

    if (reading != null && previous != null && reading.id != previous.id) {
      if (!previous.soilWet && reading.soilWet) {
        joy = min(1, joy + 0.6);
        _event(Reaction.refresh, '¡Ahh! Gracias por el agua');
      } else if (!previous.raining && reading.raining) {
        joy = min(1, joy + 0.3);
        _event(Reaction.jump, '¡Lluvia! Me encanta');
      } else if (!previous.near && reading.near && fresh) {
        joy = min(1, joy + 0.25);
        _event(Reaction.wave, '¡Hola! Te vi llegar');
      } else if (previous.dark && !reading.dark) {
        energy = 1;
        _event(Reaction.yawn, 'Buenos días, sol');
      } else if (!previous.tankLow && reading.tankLow) {
        _event(Reaction.surprise, 'El tanque se está vaciando');
      }
    } else if (previous == null && reading != null && fresh) {
      _event(Reaction.wave, '¡Hola! Ya tengo datos del jardín');
    }
    if (!_lastFresh && fresh && previous != null && reading.id != previous.id) {
      _event(Reaction.surprise, '¡Volví a tener señal!');
    }

    _last = reading;
    _lastFresh = fresh;
    if (next != _mood) {
      _mood = next;
      boredom = 0;
      _nextIdea = now.add(_idleGap());
    }
    notifyListeners();
  }

  /// Toque del usuario sobre la mascota.
  void poke() {
    final now = _now();
    _pokes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > const Duration(seconds: 2));
    boredom = 0;
    if (_mood == Mood.sleepy) {
      _event(Reaction.surprise, '¡Ay! Me despertaste… zzz', force: true);
    } else if (_mood == Mood.thirsty) {
      _event(Reaction.curious, 'Agua, por favor…', force: true);
    } else if (_pokes.length >= 3) {
      _pokes.clear();
      joy = min(1, joy + 0.3);
      _event(Reaction.dance, '¡Vamos a bailar!', force: true);
    } else {
      joy = min(1, joy + 0.12);
      _event(Reaction.giggle, _pick(['¡Jiji, cosquillas!', '¡Hey!', '¿Me buscabas?']), force: true);
    }
    notifyListeners();
  }

  /// Avanza el reloj interno. Llamar cada ~1 s.
  void tick() {
    final now = _now();
    joy = max(0.15, joy - 0.004);
    final night = now.hour >= 21 || now.hour < 7 || _mood == Mood.sleepy;
    energy = night ? max(0.2, energy - 0.003) : min(1, energy + 0.002);
    if (_mood == Mood.content || _mood == Mood.waiting || _mood == Mood.rainy) {
      boredom = min(1, boredom + 0.03);
    }
    if (now.isAfter(_busyUntil) && now.isAfter(_nextIdea)) _ownIdea();
    notifyListeners();
  }

  /// Color de las hojas: verde sano, amarillento si hay sed, apagado de noche.
  String get leafColor => switch (_mood) {
    Mood.thirsty => '#B4B54C',
    Mood.sleepy => '#6FA845',
    Mood.hot => '#9CBD47',
    Mood.cold => '#79B98A',
    _ => '#7DC24B',
  };

  // ------------------------------------------------------------------ privado

  Mood _moodFor(Reading? r, bool fresh) {
    if (r == null || !fresh) return Mood.waiting;
    if (r.raining) return Mood.rainy;
    if (!r.soilWet || r.tankLow) return Mood.thirsty;
    if (r.dark) return Mood.sleepy;
    final t = r.temperature;
    if (t != null && t >= hotC) return Mood.hot;
    if (t != null && t <= coldC) return Mood.cold;
    return Mood.content;
  }

  void _ownIdea() {
    final now = _now();
    _nextIdea = now.add(_idleGap());
    Reaction? pick;
    String? line;
    switch (_mood) {
      case Mood.content:
      case Mood.waiting:
        final options = <(Reaction, double, String)>[
          (Reaction.curious, 0.3 + boredom * 0.3, _pick(['¿Qué será eso?', 'Hmm…', 'Veo algo por allá'])),
          (Reaction.dance, joy > 0.55 ? 0.35 : 0.06, _pick(['¡Me siento genial!', 'La la la…'])),
          (Reaction.yawn, energy < 0.5 ? 0.35 : 0.06, 'Qué sueñito…'),
          (Reaction.jump, joy * 0.2, '¡Hop!'),
          (Reaction.wave, 0.08, '¡Hola!'),
        ];
        final total = options.fold<double>(0, (a, o) => a + o.$2);
        var x = _random.nextDouble() * total;
        for (final o in options) {
          x -= o.$2;
          if (x <= 0) {
            pick = o.$1;
            line = o.$3;
            break;
          }
        }
      case Mood.rainy:
        pick = _random.nextBool() ? Reaction.dance : Reaction.jump;
        line = '¡Bailo bajo la lluvia!';
      case Mood.thirsty:
        if (_random.nextDouble() < 0.4) {
          pick = Reaction.curious;
          line = '¿Alguien trae agua?';
        }
      case Mood.sleepy:
      case Mood.hot:
      case Mood.cold:
        break;
    }
    if (pick != null) {
      boredom = 0;
      _event(pick, line);
    }
  }

  Duration _idleGap() => Duration(milliseconds: 9000 + _random.nextInt(11000) - (boredom * 4000).round());

  void _event(Reaction reaction, String? line, {bool force = false}) {
    final now = _now();
    if (!force && now.isBefore(_busyUntil)) return;
    _busyUntil = now.add(Duration(milliseconds: (reaction.seconds * 1000).round()));
    if (line != null) {
      _say = line;
      _sayUntil = now.add(const Duration(seconds: 5));
    }
    onReact?.call(reaction);
  }

  String _pick(List<String> items) => items[_random.nextInt(items.length)];

  String _moodThought() {
    final r = _last;
    String n(double? v, String unit) => v == null ? '' : ' ${v.toStringAsFixed(0)} $unit';
    return switch (_mood) {
      Mood.waiting => r == null ? 'Esperando la primera lectura…' : 'Sin señal del jardín hace rato',
      Mood.thirsty => r != null && r.tankLow && r.soilWet
          ? 'El tanque está casi vacío'
          : 'La tierra está seca${r == null ? '' : ' (${r.soilPercent} %)'}',
      Mood.sleepy => 'Poca luz… a descansar',
      Mood.rainy => 'La lluvia riega el jardín',
      Mood.hot => '¡Uf, qué calor!${n(r?.temperature, '°C')}',
      Mood.cold => 'Brrr…${n(r?.temperature, '°C')}',
      Mood.content => energy < 0.5 ? 'Tranquilo y con sueñito' : 'Todo en orden, me siento bien',
    };
  }
}
