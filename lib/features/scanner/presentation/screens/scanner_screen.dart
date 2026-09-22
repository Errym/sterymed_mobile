import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../bloc/scanner_bloc.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ScannerBloc(ctx.read())..add(const ScannerReset()),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    context.read<ScannerBloc>().add(ScanDetected(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner une étiquette'),
        actions: [
          BlocBuilder<ScannerBloc, ScannerState>(
            buildWhen: (p, c) => p.torchOn != c.torchOn,
            builder: (context, state) => IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  state.torchOn ? Icons.flash_on : Icons.flash_off,
                  key: ValueKey(state.torchOn),
                ),
              ),
              tooltip: state.torchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
              onPressed: () {
                _controller.toggleTorch();
                context.read<ScannerBloc>().add(const TorchToggled());
              },
            ),
          ),
        ],
      ),
      body: BlocListener<ScannerBloc, ScannerState>(
        listenWhen: (p, c) => p.status != c.status || p.lastCode != c.lastCode,
        listener: (context, state) {
          if (state.status == ScannerStatus.resolved && state.result != null) {
            final r = state.result!;
            if (r.isBlocked) {
              context.go(Routes.labelsBlocked(r.code));
            } else if (r.label != null) {
              context.go(Routes.labelsDetail(r.code));
            }
          }
          if (state.status == ScannerStatus.error && state.error != null) {
            AppSnackbar.show(context, state.error!, kind: SnackKind.error);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            BlocBuilder<ScannerBloc, ScannerState>(
              buildWhen: (p, c) => p.status != c.status,
              builder: (context, state) => _ScanFrameOverlay(
                animation: _scanLineController,
                dimmed: state.status == ScannerStatus.cooling,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xxl,
              child: BlocBuilder<ScannerBloc, ScannerState>(
                builder: (context, state) {
                  return Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _statusWidget(state.status),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusWidget(ScannerStatus status) {
    switch (status) {
      case ScannerStatus.resolving:
        return const Column(
          key: ValueKey('resolving'),
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.4,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Vérification...',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case ScannerStatus.cooling:
        return Container(
          key: const ValueKey('cooling'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: const Text(
            'Prêt dans un instant…',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      default:
        return const Text(
          key: ValueKey('scanning'),
          'Alignez le QR code dans le cadre',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  final Animation<double> animation;
  final bool dimmed;
  const _ScanFrameOverlay({required this.animation, this.dimmed = false});

  static const _size = 260.0;
  static const _bracketLen = 32.0;
  static const _bracketThickness = 4.0;

  @override
  Widget build(BuildContext context) {
    final color = dimmed ? Colors.white38 : Colors.white;
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: dimmed ? 0.5 : 1,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            children: [
              // Corner brackets
              for (final corner in const [0, 1, 2, 3]) _corner(corner, color),
              // Animated scan line
              if (!dimmed)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Positioned(
                      top: 12 + animation.value * (_size - 24),
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandPrimary.withValues(alpha: 0),
                              AppColors.brandPrimary,
                              AppColors.brandPrimary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corner(int index, Color color) {
    final alignment = switch (index) {
      0 => Alignment.topLeft,
      1 => Alignment.topRight,
      2 => Alignment.bottomLeft,
      _ => Alignment.bottomRight,
    };
    final isTop = index < 2;
    final isLeft = index.isEven;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: _bracketLen,
        height: _bracketLen,
        child: CustomPaint(
          painter: _CornerPainter(
            color: color,
            thickness: _bracketThickness,
            isTop: isTop,
            isLeft: isLeft,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTop;
  final bool isLeft;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final y = isTop ? 0.0 : size.height;
    final x = isLeft ? 0.0 : size.width;
    path.moveTo(isLeft ? size.width : 0, y);
    path.lineTo(x, y);
    path.lineTo(x, isTop ? size.height : 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
