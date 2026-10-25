import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'angel_scan_client.dart';

/// Camera-only Angel experience. AI detection is throttled while a review is open.
/// No shutter, barcode frame, mode picker, AI status pill or source-selection controls.
class AngelAutoCameraScreen extends StatefulWidget {
  final AngelScanClient api;
  final Future<void> Function(List<Map<String, dynamic>> items, String documentHash) onRecognized;
  final bool Function()? contextIsCurrent;

  const AngelAutoCameraScreen({
    super.key,
    required this.api,
    required this.onRecognized,
    this.contextIsCurrent,
  });

  @override
  State<AngelAutoCameraScreen> createState() => _AngelAutoCameraScreenState();
}

class _AngelAutoCameraScreenState extends State<AngelAutoCameraScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _busy = false;
  bool _torch = false;
  bool _closed = false;
  DateTime _nextScan = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw StateError('No camera available');
      final rear = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _cameraIndex = rear < 0 ? 0 : rear;
      await _openCamera();
      _timer ??= Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_recognize()));
    } catch (_) {
      if (mounted) setState(() => _error = 'Camera unavailable. Check camera permission.');
    }
  }

  Future<void> _openCamera() async {
    _busy = true;
    final prior = _camera;
    _camera = null;
    await prior?.dispose();
    if (_closed) return;
    final next = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await next.initialize();
      if (_closed || !mounted) {
        await next.dispose();
        return;
      }
      _camera = next;
      _torch = false;
      _nextScan = DateTime.now().add(const Duration(seconds: 3));
      setState(() => _error = null);
    } finally {
      _busy = false;
    }
  }

  Future<void> _recognize() async {
    final controller = _camera;
    if (_closed || !mounted || _busy || controller == null ||
        !controller.value.isInitialized || controller.value.isTakingPicture ||
        DateTime.now().isBefore(_nextScan) ||
        widget.contextIsCurrent?.call() == false) return;
    _busy = true;
    // Avoid per-frame billable API calls. Recognize one settled still at a time.
    _nextScan = DateTime.now().add(const Duration(seconds: 9));
    try {
      final image = await controller.takePicture();
      final Uint8List bytes = await image.readAsBytes();
      if (!mounted || _closed || widget.contextIsCurrent?.call() == false) return;
      if (bytes.length > 4000000) return;
      // Inventory auto-detects both a single product and an itemized list.
      // POS recognizes only one sellable product.
      final result = await widget.api.recognize(
        bytes,
        document: widget.api.inventoryMode,
      );
      final items = (result['items'] as List?)
              ?.map((x) => Map<String, dynamic>.from(x as Map))
              .toList() ??
          [];
      if (items.isEmpty || !mounted || _closed) return;
      await widget.onRecognized(items, (result['document_hash'] ?? '').toString());
      // Avoid immediately submitting the same object after closing review.
      _nextScan = DateTime.now().add(const Duration(seconds: 9));
    } catch (_) {
      // False detections, blurry images, rate limits and transient network failures
      // should not show an interrupting overlay over the clear camera.
    } finally {
      _busy = false;
    }
  }

  Future<void> _flip() async {
    if (_busy || _cameras.length < 2) return;
    final current = _cameras[_cameraIndex].lensDirection;
    final target = _cameras.indexWhere((c) => c.lensDirection != current);
    _cameraIndex = target >= 0 ? target : (_cameraIndex + 1) % _cameras.length;
    try { await _openCamera(); } catch (_) {
      if (mounted) setState(() => _error = 'Unable to switch camera.');
    }
  }

  Future<void> _toggleLight() async {
    if (_busy || _camera == null) return;
    try {
      await _camera!.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {/* A camera may not have a torch. */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_closed && _camera == null) {
      unawaited(_initialize());
    } else if (state != AppLifecycleState.resumed) {
      _busy = true;
      final old = _camera;
      _camera = null;
      unawaited(old?.dispose());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (controller != null && controller.value.isInitialized)
          Center(child: SizedBox.expand(child: CameraPreview(controller)))
        else if (_error != null)
          Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: const TextStyle(color: Colors.white)),
          )),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.filledTonal(
                  tooltip: 'Light',
                  onPressed: _toggleLight,
                  icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                ),
                const SizedBox(width: 42),
                IconButton.filledTonal(
                  tooltip: 'Flip camera',
                  onPressed: _flip,
                  icon: const Icon(Icons.flip_camera_ios_rounded),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
