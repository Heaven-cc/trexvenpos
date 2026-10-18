import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import 'product_provider.dart';
import 'product_repository.dart';
import 'quick_add_screen.dart';
import '../auth/permission_service.dart';

/// Optional integration hook. The caller must resolve the permitted price tier
/// and add the product through the EXISTING cart workflow.
/// Returns true only after the cart was actually updated.
typedef ScannedProductHandler = Future<bool> Function(
    Product product, String scanEventId,
    );

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, this.onProductMatched});

  /// When null, preserves the legacy Navigator.pop(product) contract.
  final ScannedProductHandler? onProductMatched;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();

  late final AnimationController _scanAnimationController;
  late final Animation<double> _scanAnimation;

  bool _isProcessing = false;
  bool _torchEnabled = false;
  // Lock the last successfully added barcode until another barcode is seen or
  // the employee explicitly enables an intentional repeat scan.
  String? _lastAddedBarcode;
  String? _scanFeedback;

  @override
  void initState() {
    super.initState();

    _scanAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scanAnimationController.stop();
      _scanAnimationController.value = .5;
    } else if (!_scanAnimationController.isAnimating) {
      _scanAnimationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    // Continuous scanning: suppress repeated frames of the already-added item.
    // A different barcode unlocks the previous product automatically.
    if (code == _lastAddedBarcode) return;

    final businessId = ref.read(authStateProvider).activeBusiness?.id;
    if (businessId == null || businessId.isEmpty) {
      _showError('No active business is selected.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _scanFeedback = null;
    });

    try {
      // Stopping the camera is inside the try block: stop() can fail.
      await _scannerController.stop();
      if (!mounted) return;
      final repository = ref.read(productRepositoryProvider);
      final product = await repository.findProductByBarcode(code, businessId);
      if (!mounted) return;

      if (product == null) {
        await _showProductNotFoundSheet(code);
        return;
      }

      if (widget.onProductMatched == null) {
        // Compatibility with all existing ScannerScreen() callers.
        Navigator.pop(context, product);
        return;
      }

      // Do not choose a price tier here. The host callback must use its
      // existing authorized checkout/pricing workflow.
      final scanEventId = const Uuid().v4();
      final didAdd = await widget.onProductMatched!(product, scanEventId);
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        if (didAdd) {
          _lastAddedBarcode = code;
          _scanFeedback = 'Added to checkout';
        } else {
          _scanFeedback = 'Product not added. Check price or permissions.';
        }
      });
      await _restartCamera();
    } on DuplicateBarcode catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError(error.message.toString());
      await _restartCamera();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Unable to scan this product. Please try again.');
      await _restartCamera();
    }
  }

  Future<void> _restartCamera() async {
    if (!mounted) return;
    try {
      await _scannerController.start();
    } catch (_) {
      _showError('Unable to restart camera. Reopen the scanner or use search.');
    }
  }

  void _allowRepeatScan() {
    setState(() {
      _lastAddedBarcode = null;
      _scanFeedback = null;
    });
  }

  Future<void> _showProductNotFoundSheet(String barcode) async {
    final canAdd = ref.read(permissionServiceProvider).canQuickAddProduct;
    final shouldAdd = await showModalBottomSheet<bool>(
      sheetAnimationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.page)),
context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                ),

                SizedBox(height: 28),

                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                SizedBox(height: PosSpace.md),

                Text(
                  'Product Not Found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'This barcode is not currently in your inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: TrexvenFontSize.input,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          barcode,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: TrexvenFontSize.input,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: PosSpace.xl),

                if (canAdd)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: TrexvenSpacing.buttonHeight,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        style: Theme.of(context).elevatedButtonTheme.style,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline),
                            SizedBox(width: 8),
                            Text(
                              'Add Product',
                              style: TextStyle(
                                fontSize: TrexvenFontSize.input,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                SizedBox(height: 12),

                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: TrexvenSpacing.buttonHeight,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                      child: Text(
                        'Scan Another Product',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.input,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (shouldAdd == true &&
        ref.read(permissionServiceProvider).canQuickAddProduct) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuickAddScreen(initialBarcode: barcode),
        ),
      );

      if (!mounted) {
        return;
      }

      if (result != null) {
        if (result is Product && widget.onProductMatched != null) {
          try {
            final added = await widget.onProductMatched!(
              result, const Uuid().v4(),
            );
            if (!mounted) return;
            setState(() {
              _isProcessing = false;
              _scanFeedback = added
                  ? 'Added to checkout'
                  : 'Product not added. Check price or permissions.';
              if (added) _lastAddedBarcode = barcode;
            });
            await _restartCamera();
          } catch (_) {
            if (!mounted) return;
            setState(() => _isProcessing = false);
            _showError('Unable to add the new product to checkout.');
            await _restartCamera();
          }
          return;
        }
        Navigator.pop(context, result);
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
    });

    await _restartCamera();
  }

  void _toggleTorch() {
    setState(() {
      _torchEnabled = !_torchEnabled;
    });

    _scannerController.toggleTorch();
  }

  void _switchCamera() {
    _scannerController.switchCamera();
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
    body: Stack(fit: StackFit.expand, children: [
      MobileScanner(controller: _scannerController, onDetect: _onDetect),
      _ScannerOverlay(animation: _scanAnimation),
      SafeArea(child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            _GlassButton(icon: Icons.close_rounded, onPressed: () => Navigator.pop(context)),
            const Expanded(child: Text('Angel Scan', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
            const SizedBox(width: 48),
          ]),
          SizedBox(height: (box.maxHeight * .42).clamp(100, 300).toDouble()),
          const Text('Place the barcode inside the frame', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Scan a product barcode to find it in your business catalog.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
          if (_scanFeedback != null) ...[
            const SizedBox(height: 12),
            Text(_scanFeedback!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            if (_lastAddedBarcode != null)
              TextButton.icon(onPressed: _allowRepeatScan, icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                label: const Text('Scan same item again', style: TextStyle(color: Colors.white))),
          ],
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _GlassButton(icon: _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded, onPressed: _toggleTorch),
            const SizedBox(width: 16),
            _GlassButton(icon: Icons.flip_camera_ios_rounded, onPressed: _switchCamera),
          ]),
          if (_isProcessing) const Padding(padding: EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12), Flexible(child: Text('Checking inventory…', style: TextStyle(color: Colors.white))),
            ])),
        ])))),
    ]));
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final label = icon == Icons.close_rounded ? 'Close scanner'
        : icon == Icons.flip_camera_ios_rounded ? 'Switch camera' : 'Toggle flashlight';
    return Semantics(button: true, label: label, child: Tooltip(message: label, child: Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    )));
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _ScannerOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ScannerPainter(progress: animation.value),
          );
        },
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double progress;

  _ScannerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.78;
    const frameHeight = 190.0;

    final left = (size.width - frameWidth) / 2;

    final top = (size.height - frameHeight) / 2 - 20;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, frameWidth, frameHeight),
      Radius.circular(24),
    );

    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.48);

    final fullPath = Path()..addRect(Offset.zero & size);

    final framePath = Path()..addRRect(frameRect);

    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      framePath,
    );

    canvas.drawPath(combinedPath, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(frameRect, borderPaint);

    final scanY = top + (frameHeight * progress);

    final scanPaint = Paint()
      ..color = TrexvenTheme.primaryBlue
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(left + 16, scanY),
      Offset(left + frameWidth - 16, scanY),
      scanPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;

    // Top-left
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top),
      Offset(left + frameWidth, top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left + frameWidth, top),
      Offset(left + frameWidth, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(left, top + frameHeight - cornerLength),
      Offset(left, top + frameHeight),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left, top + frameHeight),
      Offset(left + cornerLength, top + frameHeight),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left + frameWidth, top + frameHeight - cornerLength),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
