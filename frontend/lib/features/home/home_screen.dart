import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../providers/search_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording  = false;
  bool _cameraReady  = false;

  late final AnimationController _shutterPulse;
  late final Animation<double>   _shutterRingAnim;

  @override
  void initState() {
    super.initState();

    // Subtle idle pulse ring on shutter button
    _shutterPulse = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: false);

    _shutterRingAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shutterPulse, curve: Curves.easeOut),
    );

    _initCamera();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).reset();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (_) {}
  }

  Future<void> _captureImage() async {
    if (!_cameraReady || _cameraController == null) return;
    try {
      final xFile = await _cameraController!.takePicture();
      ref.read(searchProvider.notifier).captureImage(xFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xFile  = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;
    ref.read(searchProvider.notifier).captureImage(xFile.path);
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path != null) ref.read(searchProvider.notifier).captureAudio(path);
  }

  Future<void> _openTextSearch() async {
    final ctrl = TextEditingController();
    final submitted = await showModalBottomSheet<String>(
      context:         context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TextSearchSheet(controller: ctrl),
    );
    if (submitted != null && submitted.isNotEmpty && mounted) {
      ref.read(searchProvider.notifier).captureText(submitted);
      _goSearch();
    }
  }

  void _goSearch() {
    ref.read(searchProvider.notifier).analyzeInputs();
    context.push('/processing');
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recorder.dispose();
    _shutterPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(searchProvider);
    final hasImage  = state.capturedImagePath != null;
    final hasAudio  = state.capturedAudioPath != null;
    final hasText   = state.capturedText != null && state.capturedText!.isNotEmpty;
    final hasInput  = hasImage || hasAudio || hasText;

    final instruction = _isRecording
        ? 'Release to finish recording…'
        : hasImage && hasAudio
            ? 'Both ready — tap Search!'
            : hasImage
                ? 'Image ready · Hold mic for voice hint'
                : hasAudio
                    ? 'Voice ready · Tap camera for photo'
                    : hasText
                        ? 'Text ready — tap Search!'
                        : 'Point at a product and tap the shutter';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ─────────────────────────────────────────────────
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(
              color: AppTheme.background,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color:       AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text('Starting camera…',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            ),

          // ── Captured-image preview ─────────────────────────────────────────
          if (hasImage) ...[
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.65))),
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: Image.file(
                  File(state.capturedImagePath!),
                  fit:          BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          // ── Dark vignette gradient ──────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.80),
                  ],
                  stops: const [0.0, 0.22, 0.60, 1.0],
                ),
              ),
            ),
          ),

          // ── Scanner corner brackets ─────────────────────────────────────────
          if (!hasImage)
            const Positioned.fill(child: _ScanBrackets()),

          // ── Top instruction bar ─────────────────────────────────────────────
          Positioned(
            top:   48,
            left:  20,
            right: 20,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key:     ValueKey(instruction),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color:        Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24),
                    border:       Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    instruction,
                    style: const TextStyle(
                      color:    Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // ── Input badges (top-right) ────────────────────────────────────────
          Positioned(
            top:   104,
            right: 18,
            child: Column(
              children: [
                if (hasImage)
                  _InputBadge(
                    icon:    Icons.image_rounded,
                    label:   'Photo',
                    color:   AppTheme.primary,
                    onClear: () => ref.read(searchProvider.notifier).clearImage(),
                  ),
                if (hasAudio) ...[
                  if (hasImage) const SizedBox(height: 8),
                  _InputBadge(
                    icon:    Icons.mic_rounded,
                    label:   'Audio',
                    color:   Colors.orange,
                    onClear: () => ref.read(searchProvider.notifier).clearAudio(),
                  ),
                ],
                if (hasText) ...[
                  if (hasImage || hasAudio) const SizedBox(height: 8),
                  _InputBadge(
                    icon:    Icons.keyboard_rounded,
                    label:   'Text',
                    color:   AppTheme.primaryLight,
                    onClear: () => ref.read(searchProvider.notifier).clearText(),
                  ),
                ],
              ],
            ),
          ),

          // ── 'AI' label (branding) ───────────────────────────────────────────
          Positioned(
            top: 52,
            left: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient:     AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'GO4',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search button ───────────────────────────────────────────────────
          if (hasInput)
            Positioned(
              bottom: 148,
              left:   32,
              right:  32,
              child: _SearchButton(onPressed: _goSearch),
            ),

          // ── Bottom control bar ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left:   0,
            right:  0,
            child: _ControlBar(
              isRecording:    _isRecording,
              hasAudio:       hasAudio,
              hasImage:       hasImage,
              hasText:        hasText,
              shutterRingAnim: _shutterRingAnim,
              onMicDown:      _startRecording,
              onMicUp:        _stopRecording,
              onShutter:      _captureImage,
              onGallery:      _pickFromGallery,
              onType:         _openTextSearch,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search button ────────────────────────────────────────────────────────────

class _SearchButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SearchButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:        AppTheme.primary.withValues(alpha: 0.45),
            blurRadius:   20,
            spreadRadius: 0,
            offset:       const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize:     const Size.fromHeight(54),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon:  const Icon(Icons.search_rounded, size: 22),
        label: const Text(
          'Search with AI',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

// ─── Control bar ──────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final bool     isRecording;
  final bool     hasAudio;
  final bool     hasImage;
  final bool     hasText;
  final Animation<double> shutterRingAnim;
  final VoidCallback onMicDown;
  final VoidCallback onMicUp;
  final VoidCallback onShutter;
  final VoidCallback onGallery;
  final VoidCallback onType;

  const _ControlBar({
    required this.isRecording,
    required this.hasAudio,
    required this.hasImage,
    required this.hasText,
    required this.shutterRingAnim,
    required this.onMicDown,
    required this.onMicUp,
    required this.onShutter,
    required this.onGallery,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 18, left: 16, right: 16,
            bottom: bottomPad + 18,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Hold-to-record mic
              GestureDetector(
                onLongPressStart: (_) => onMicDown(),
                onLongPressEnd:   (_) => onMicUp(),
                child: _ControlBtn(
                  icon:        Icons.mic_rounded,
                  label:       isRecording ? 'Release' : 'Hold',
                  active:      isRecording,
                  activeColor: Colors.redAccent,
                  hasBadge:    hasAudio && !isRecording,
                ),
              ),

              // Shutter (center + larger)
              _ShutterButton(
                hasImage:        hasImage,
                ringAnim:        shutterRingAnim,
                onTap:           onShutter,
              ),

              // Gallery
              GestureDetector(
                onTap: onGallery,
                child: const _ControlBtn(
                  icon:     Icons.photo_library_rounded,
                  label:    'Gallery',
                  hasBadge: false,
                ),
              ),

              // Type
              GestureDetector(
                onTap: onType,
                child: _ControlBtn(
                  icon:     Icons.keyboard_alt_rounded,
                  label:    'Type',
                  hasBadge: hasText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shutter button ───────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  final bool              hasImage;
  final Animation<double> ringAnim;
  final VoidCallback      onTap;

  const _ShutterButton({
    required this.hasImage,
    required this.ringAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width:  84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Idle pulse ring (only when no image yet)
            if (!hasImage)
              AnimatedBuilder(
                animation: ringAnim,
                builder: (_, __) {
                  final t       = ringAnim.value;
                  final scale   = 1.0 + t * 0.4;
                  final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width:  78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape:  BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: opacity),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Main button circle
            Container(
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasImage
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.18),
                border: Border.all(
                  color: hasImage ? AppTheme.primary : Colors.white,
                  width: 3.5,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: hasImage
                      ? const Icon(Icons.restart_alt_rounded,
                          key: ValueKey('retake'), color: Colors.white, size: 30)
                      : const Icon(Icons.camera_alt_rounded,
                          key: ValueKey('capture'), color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scan brackets ────────────────────────────────────────────────────────────

class _ScanBrackets extends StatelessWidget {
  const _ScanBrackets();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BracketPainter());
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bracketLen  = 28.0;
    const cornerRadius = 4.0;
    const strokeWidth  = 3.0;

    final cx = size.width  / 2;
    final cy = size.height / 2;

    // Frame: 56% of width, 36% of height
    final fw = size.width  * 0.56;
    final fh = size.height * 0.36;

    final left   = cx - fw / 2;
    final top    = cy - fh / 2;
    final right  = cx + fw / 2;
    final bottom = cy + fh / 2;

    final paint = Paint()
      ..color       = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(left + cornerRadius, top), Offset(left + bracketLen, top), paint);
    canvas.drawLine(Offset(left, top + cornerRadius), Offset(left, top + bracketLen), paint);
    canvas.drawArc(Rect.fromLTWH(left, top, cornerRadius * 2, cornerRadius * 2),
        3.14159, 1.5708, false, paint);

    // Top-right
    canvas.drawLine(Offset(right - bracketLen, top), Offset(right - cornerRadius, top), paint);
    canvas.drawLine(Offset(right, top + cornerRadius), Offset(right, top + bracketLen), paint);
    canvas.drawArc(Rect.fromLTWH(right - cornerRadius * 2, top, cornerRadius * 2, cornerRadius * 2),
        -1.5708, 1.5708, false, paint);

    // Bottom-left
    canvas.drawLine(Offset(left + cornerRadius, bottom), Offset(left + bracketLen, bottom), paint);
    canvas.drawLine(Offset(left, bottom - bracketLen), Offset(left, bottom - cornerRadius), paint);
    canvas.drawArc(Rect.fromLTWH(left, bottom - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2),
        1.5708, 1.5708, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(right - bracketLen, bottom), Offset(right - cornerRadius, bottom), paint);
    canvas.drawLine(Offset(right, bottom - bracketLen), Offset(right, bottom - cornerRadius), paint);
    canvas.drawArc(Rect.fromLTWH(right - cornerRadius * 2, bottom - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2),
        0, 1.5708, false, paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

// ─── Control button ───────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final Color    activeColor;
  final bool     hasBadge;

  const _ControlBtn({
    required this.icon,
    required this.label,
    this.active      = false,
    this.activeColor = Colors.redAccent,
    this.hasBadge    = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration:     const Duration(milliseconds: 200),
              width:        52,
              height:       52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? activeColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.12),
                border: active
                    ? Border.all(color: activeColor.withValues(alpha: 0.7), width: 1.5)
                    : null,
              ),
              child: Icon(
                icon,
                color: active ? activeColor : Colors.white70,
                size:  24,
              ),
            ),
            if (hasBadge)
              Positioned(
                right: -1,
                top:   -1,
                child: Container(
                  width:  11,
                  height: 11,
                  decoration: BoxDecoration(
                    color:  AppTheme.accent,
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color:    Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Input badge ──────────────────────────────────────────────────────────────

class _InputBadge extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onClear;

  const _InputBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap:  onClear,
            child: Icon(Icons.close_rounded, size: 13, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Text search bottom sheet ─────────────────────────────────────────────────

class _TextSearchSheet extends StatelessWidget {
  final TextEditingController controller;
  const _TextSearchSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color:        AppTheme.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
          ),
          padding: EdgeInsets.only(
            left:   20,
            right:  20,
            top:    16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Search by text',
                style: TextStyle(
                  color:      AppTheme.onSurface,
                  fontSize:   17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus:  true,
                style:      const TextStyle(color: AppTheme.onSurface),
                decoration: InputDecoration(
                  hintText:  'e.g. red running shoes Nike size 10',
                  hintStyle: const TextStyle(color: Color(0xFF666688)),
                  filled:    true,
                  fillColor: AppTheme.surfaceHigh,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.primary,
                    size:  22,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppTheme.primary, size: 20),
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:   BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppTheme.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI will analyze your description and find matching products',
                style: TextStyle(color: Color(0xFF666688), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
