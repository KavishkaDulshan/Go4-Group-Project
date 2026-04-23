import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/particle_background.dart';
import '../../providers/search_provider.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _breatheController;
  late final AnimationController _dotsController;

  late final Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();

    // Expanding pulse rings
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Orb breathing (gentle scale in/out)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // Dots cycling
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // ── Route on status changes ───────────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(
        searchProvider.select((s) => s.status),
        (_, status) {
          if (!mounted) return;
          if (status == SearchStatus.analyzed) {
            context.go('/filters');
          } else if (status == SearchStatus.success) {
            context.go('/results');
          } else if (status == SearchStatus.error) {
            final msg =
                ref.read(searchProvider).errorMessage ?? 'Search failed. Please try again.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(msg)),
                  ],
                ),
              ),
            );
            context.pop();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _breatheController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(searchProvider);
    final isAnalyzing = state.status == SearchStatus.analyzing;

    final title    = isAnalyzing ? 'Analysing' : 'Searching';
    final subtitle = isAnalyzing
        ? 'AI is understanding your inputs'
        : 'AI is browsing products for you';
    final hint = isAnalyzing
        ? 'Detecting product · Generating smart filters'
        : 'Searching across thousands of listings';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Particle background ─────────────────────────────────────────
          const ParticleBackground(count: 80),

          // ── 2. Centered soft glow ──────────────────────────────────────────
          Center(
            child: Container(
              width:  340,
              height: 340,
              decoration: const BoxDecoration(
                shape:    BoxShape.circle,
                gradient: AppTheme.centerGlow,
              ),
            ),
          ),

          // ── 3. Content ────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Orb + rings
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_ringController, _breatheController]),
                  builder: (_, __) => _OrbWidget(
                    isAnalyzing:  isAnalyzing,
                    ringProgress: _ringController.value,
                    breatheScale: _breatheAnim.value,
                  ),
                ),

                const SizedBox(height: 48),

                // Title with animated dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize:      MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: ShaderMask(
                        key:         ValueKey(isAnalyzing),
                        blendMode:   BlendMode.srcIn,
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize:      28,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: _dotsController,
                      builder: (_, __) =>
                          _AnimatedDots(progress: _dotsController.value),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Subtitle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    subtitle,
                    key: ValueKey('sub_$isAnalyzing'),
                    style: const TextStyle(
                      color:    AppTheme.onSurfaceMid,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  hint,
                  style: const TextStyle(
                    color:    AppTheme.onSurfaceMid,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Attribute chips (search phase)
                if (!isAnalyzing &&
                    state.result != null &&
                    state.result!.tags.chips.isNotEmpty)
                  _ChipsRow(chips: state.result!.tags.chips),

                // Detected product name (analyze phase)
                if (isAnalyzing && state.analyzedTags != null)
                  _DetectedProduct(
                    name: state.analyzedTags!['productName'] as String? ?? '',
                  ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Orb ──────────────────────────────────────────────────────────────────────

class _OrbWidget extends StatelessWidget {
  final bool   isAnalyzing;
  final double ringProgress;
  final double breatheScale;

  const _OrbWidget({
    required this.isAnalyzing,
    required this.ringProgress,
    required this.breatheScale,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Two offset pulse rings
          _PulseRing(
            progress:  ringProgress,
            color:     AppTheme.primary,
            maxRadius: 90,
          ),
          _PulseRing(
            progress:  (ringProgress + 0.5) % 1.0,
            color:     AppTheme.accent,
            maxRadius: 90,
          ),

          // Breathing glow orb
          Transform.scale(
            scale: breatheScale,
            child: Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3FB465),
                    Color(0xFF2DA44E),
                    Color(0xFF1A7F37),
                  ],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:        AppTheme.primary.withValues(alpha: 0.55),
                    blurRadius:   40,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    color:        AppTheme.accent.withValues(alpha: 0.25),
                    blurRadius:   60,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isAnalyzing
                        ? Icons.psychology_rounded
                        : Icons.auto_awesome_rounded,
                    key:   ValueKey(isAnalyzing),
                    size:  44,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulse ring ───────────────────────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  final double progress;   // 0–1
  final Color  color;
  final double maxRadius;

  const _PulseRing({
    required this.progress,
    required this.color,
    required this.maxRadius,
  });

  @override
  Widget build(BuildContext context) {
    final eased   = Curves.easeOut.transform(progress);
    final size    = maxRadius * 2 * (0.48 + eased * 0.9);
    final opacity = (1.0 - eased).clamp(0.0, 1.0) * 0.55;

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

// ─── Animated dots ────────────────────────────────────────────────────────────

class _AnimatedDots extends StatelessWidget {
  final double progress; // 0–1

  const _AnimatedDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    final step = (progress * 3).floor().clamp(0, 2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final lit = i <= step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(right: 3),
          width:  lit ? 8 : 5,
          height: lit ? 8 : 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? AppTheme.primaryLight : Colors.white.withValues(alpha: 0.2),
          ),
        );
      }),
    );
  }
}

// ─── Chips row ────────────────────────────────────────────────────────────────

class _ChipsRow extends StatelessWidget {
  final List<String> chips;
  const _ChipsRow({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Detected:',
          style: TextStyle(color: Color(0xFF666688), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing:   8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: chips
              .take(6)
              .map((c) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color:        AppTheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        color:      AppTheme.primaryLight,
                        fontSize:   12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Detected product pill ─────────────────────────────────────────────────────

class _DetectedProduct extends StatelessWidget {
  final String name;
  const _DetectedProduct({required this.name});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color:        AppTheme.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppTheme.accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 15, color: AppTheme.accent),
          const SizedBox(width: 7),
          Text(
            name,
            style: const TextStyle(
              color:      AppTheme.accent,
              fontSize:   13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
