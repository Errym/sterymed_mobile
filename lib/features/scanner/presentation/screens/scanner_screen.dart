import 'package:steriymed_mobile/core/utils/dispose_later.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../bloc/scanner_bloc.dart';
import 'package:flutter/services.dart';

class ScannerScreen extends StatelessWidget {
  /// Opens on the product lookup (barcode, reference, lot) instead of the
  /// sterilization-label scan, e.g. from the stock search bar.
  final bool startInProductMode;

  const ScannerScreen({super.key, this.startInProductMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ScannerBloc(ctx.read())..add(const ScannerReset()),
      child: _ScannerView(startInProductMode: startInProductMode),
    );
  }
}

class _ScannerView extends StatefulWidget {
  final bool startInProductMode;
  const _ScannerView({this.startInProductMode = false});

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _controller;
  late final AnimationController _scanLineController;

  /// `false`: the code is a sterilization label. `true`: it is a product
  /// barcode, reference or lot number, answered by the stock lookup.
  late bool _productMode = widget.startInProductMode;
  bool _lookingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  /// `MobileScanner` only manages the camera across app lifecycle changes when
  /// it owns its controller; ours is shared with the torch button, so this
  /// screen does it. Coming back from the system settings (where the camera
  /// permission may just have been granted) restarts the camera too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _restartCamera();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _controller.stop().catchError((_) {});
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _restartCamera() async {
    if (!mounted || _controller.value.isRunning) return;
    try {
      await _controller.start();
    } catch (_) {
      // Still refused or unavailable: the preview keeps showing the
      // explanatory panel, which offers the retry and the manual entry.
    }
  }

  /// The camera may be refused, broken or useless in poor light: the code
  /// printed under the label can be typed instead. It goes through exactly the
  /// same single lookup as a scan.
  Future<void> _enterCodeManually() async {
    final bloc = context.read<ScannerBloc>();
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisir le code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _productMode
                ? 'Code-barres, référence ou numéro de lot'
                : 'Code ou identifiant de l\'étiquette',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Vérifier'),
          ),
        ],
      ),
    );
    disposeControllerLater(controller);
    if (code == null || code.isEmpty) return;
    if (_productMode) {
      await _openProduct(code);
      return;
    }
    bloc.add(ScanDetected(code));
  }

  /// A product code never touches the label bloc: it opens the read-only
  /// stock lookup. One lookup at a time, however many frames see the code.
  Future<void> _openProduct(String code) async {
    if (_lookingUp || !mounted) return;
    _lookingUp = true;
    HapticFeedback.lightImpact();
    try {
      await context.push(Routes.codeLookup(code));
    } finally {
      _lookingUp = false;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    if (_productMode) {
      _openProduct(raw);
      return;
    }
    context.read<ScannerBloc>().add(ScanDetected(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_productMode ? 'Scanner un produit' : 'Scanner une étiquette'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SegmentedButton<bool>(
              key: const ValueKey('scan_mode'),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white70,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: Colors.white,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Étiquette'),
                  icon: Icon(Icons.qr_code_2),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Produit'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_productMode},
              onSelectionChanged: (s) =>
                  setState(() => _productMode = s.first),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Saisir le code',
            onPressed: _enterCodeManually,
          ),
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
          // A blocked label (recalled/expired/voided) never comes back as
          // a resolved success — the real backend always throws instead
          // (see BACKEND_BUGS.md's Labeling coherence-sweep notes). Route
          // there specifically for those three error codes; any other
          // error (not found, network, ...) just shows the snackbar
          // below and lets the user try again.
          if (state.status == ScannerStatus.resolved &&
              state.result != null &&
              state.lastCode != null) {
            HapticFeedback.lightImpact();
            context.openRoute(Routes.labelsDetail(state.lastCode!));
          } else if (state.status == ScannerStatus.error &&
              state.lastCode != null &&
              const {
                'LABEL_EXPIRED',
                'LABEL_RECALLED',
                'LABEL_VOIDED',
              }.contains(state.errorCode)) {
            context.openRoute(Routes.labelsBlocked(state.lastCode!));
          } else if (state.status == ScannerStatus.error &&
              state.error != null) {
            AppSnackbar.show(context, state.error!, kind: SnackKind.error);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraUnavailable(
                denied:
                    error.errorCode == MobileScannerErrorCode.permissionDenied,
                onManualEntry: _enterCodeManually,
                onRetry: _restartCamera,
                onOpenSettings: openAppSettings,
              ),
            ),
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
                        child: _productMode
                            ? const Text(
                                key: ValueKey('product_hint'),
                                'Scannez le code-barres du produit ou du lot',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : _statusWidget(state.status),
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

/// Shown instead of the camera preview when it cannot start. The label can
/// still be looked up by typing its code.
class _CameraUnavailable extends StatelessWidget {
  final bool denied;
  final VoidCallback onManualEntry;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  const _CameraUnavailable({
    required this.denied,
    required this.onManualEntry,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                denied
                    ? 'L\'accès à la caméra est refusé. Autorisez-le dans les '
                          'réglages de l\'appareil, ou saisissez le code.'
                    : 'La caméra est indisponible. Saisissez le code de '
                          'l\'étiquette.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Saisir le code'),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (denied)
                TextButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Ouvrir les réglages'),
                )
              else
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
