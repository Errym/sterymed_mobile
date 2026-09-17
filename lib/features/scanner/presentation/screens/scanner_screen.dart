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

class _ScannerViewState extends State<_ScannerView> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
              icon: Icon(state.torchOn ? Icons.flash_on : Icons.flash_off),
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
        listenWhen: (p, c) =>
            p.status != c.status || p.lastCode != c.lastCode,
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
            const _ScanFrameOverlay(),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xxl,
              child: BlocBuilder<ScannerBloc, ScannerState>(
                builder: (context, state) {
                  final isResolving =
                      state.status == ScannerStatus.resolving;
                  return Column(
                    children: [
                      if (isResolving)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Alignez le QR code dans le cadre',
                        style: AppTypography.bodyStrong.copyWith(
                          color: Colors.white,
                        ),
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
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
