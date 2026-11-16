import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class MascotCard extends StatefulWidget {
  const MascotCard({super.key, required this.state});
  final String state;

  @override
  State<MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends State<MascotCard> {
  final Flutter3DController controller = Flutter3DController();
  bool _modelLoaded = false;

  static const scenes = <String, (Color, Color, String, String, IconData)>{
    'idle': (
      Color(0xFF174D3D),
      Color(0xFF2B8160),
      'Jardín en calma',
      'Tu plantita está tranquila',
      Icons.wb_sunny_outlined,
    ),
    'rain': (
      Color(0xFF173C56),
      Color(0xFF426D84),
      'Día de lluvia',
      'La lluvia riega el jardín',
      Icons.water_drop_outlined,
    ),
    'happy': (
      Color(0xFF287243),
      Color(0xFF69A96B),
      '¡Hola, jardinero!',
      'Tu plantita te saluda',
      Icons.auto_awesome_outlined,
    ),
    'thirsty': (
      Color(0xFF8C4A25),
      Color(0xFFD08A4E),
      'Necesita agua',
      'Revisa tierra y tanque',
      Icons.opacity_outlined,
    ),
    'sleep': (
      Color(0xFF202E49),
      Color(0xFF435276),
      'Hora de descansar',
      'Hay poca luz en el jardín',
      Icons.nightlight_outlined,
    ),
  };

  @override
  void didUpdateWidget(covariant MascotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _playStateAnimation();
  }

  void _playStateAnimation() {
    if (!_modelLoaded) return;
    final state = scenes.containsKey(widget.state) ? widget.state : 'idle';
    controller.playAnimation(
      animationName: state[0].toUpperCase() + state.substring(1),
      loopCount: state == 'happy' ? 1 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = scenes.containsKey(widget.state) ? widget.state : 'idle';
    final scene = scenes[state]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 550),
      height: 390,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scene.$1, scene.$2],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: 48,
            child: _Glow(color: Colors.white.withValues(alpha: .08), size: 210),
          ),
          Positioned(
            left: -35,
            bottom: -90,
            child: _Glow(color: Colors.white.withValues(alpha: .07), size: 220),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 28, bottom: 20),
              child: Flutter3DViewer(
                controller: controller,
                enableTouch: false,
                src: 'assets/mascot/mascot_shared.glb',
                onLoad: (_) {
                  _modelLoaded = true;
                  controller.setCameraTarget(0, 0.49, 0);
                  controller.setCameraOrbit(0, 75, 88);
                  _playStateAnimation();
                },
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 18,
            child: Row(
              children: [
                Icon(scene.$5, color: const Color(0xFFE9F5DF), size: 19),
                const SizedBox(width: 8),
                Text(
                  'ESTADO DEL JARDÍN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.$3,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scene.$4,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
