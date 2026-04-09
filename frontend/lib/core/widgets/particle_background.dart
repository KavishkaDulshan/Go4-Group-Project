import 'dart:math';
import 'package:flutter/material.dart';

/// Floating particle animation inspired by Google's anti-gravity visual effect.
///
/// Renders [count] small glowing orbs that drift upward with a gentle sine
/// sway, fading in near the bottom and fading out near the top — creating a
/// deep-space parallax effect on dark backgrounds.
class ParticleBackground extends StatefulWidget {
  final int count;

  const ParticleBackground({super.key, this.count = 70});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _palette = [
    Color(0xFF2DA44E), // forest green
    Color(0xFF3FB465), // lighter green
    Color(0xFF56D364), // bright green
    Color(0xFFE8912D), // warm amber
    Color(0xFFF0A732), // bright amber
    Color(0xFF58A6FF), // soft blue
    Color(0xFF89D4A0), // pale green
    Color(0xFFFFFFFF), // white
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    final rng = Random();
    _particles = List.generate(
      widget.count,
      (_) => _Particle.random(rng, _palette),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(_particles, _controller.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─── Data ──────────────────────────────────────────────────────────────────────

class _Particle {
  final double baseX; // normalized 0–1 horizontal position
  final double phase; // normalized 0–1 vertical offset (stagger)
  final double speed; // loop speed multiplier
  final double radius; // paint radius in logical pixels
  final Color color;
  final double drift; // horizontal sway phase offset

  const _Particle({
    required this.baseX,
    required this.phase,
    required this.speed,
    required this.radius,
    required this.color,
    required this.drift,
  });

  factory _Particle.random(Random rng, List<Color> palette) => _Particle(
        baseX: rng.nextDouble(),
        phase: rng.nextDouble(),
        speed: 0.2 + rng.nextDouble() * 0.8,
        radius: 1.2 + rng.nextDouble() * 4.5,
        color: palette[rng.nextInt(palette.length)],
        drift: rng.nextDouble() * 2 * pi,
      );
}

// ─── Painter ───────────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0–1 animation progress

  const _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // vp: normalized vertical position 0→1, wraps continuously
      final vp = (p.phase + t * p.speed) % 1.0;

      // y progresses from bottom (vp=0) to top (vp=1)
      final y = size.height * (1.0 - vp);

      // gentle horizontal sine sway
      final x = size.width * p.baseX +
          sin(vp * 5 * pi + p.drift) * (size.width * 0.025);

      // alpha envelope: ramp in 0→0.25, full 0.25→0.75, ramp out 0.75→1
      double alpha;
      if (vp < 0.25) {
        alpha = vp / 0.25;
      } else if (vp > 0.75) {
        alpha = (1.0 - vp) / 0.25;
      } else {
        alpha = 1.0;
      }
      alpha = (alpha * 0.65).clamp(0.0, 1.0);

      // soft glow via blur
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 0.9);

      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
