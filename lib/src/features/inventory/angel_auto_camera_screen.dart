import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'angel_scan_client.dart';
import 'angel_document_reader.dart';

/// Only one recognition/review can own the camera at a time.
class AngelAutoCameraScreen extends StatefulWidget {
  final AngelScanClient api;
  final Future<void> Function(Map<String, dynamic> result, bool singleProduct)
  onRecognized;
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

class _AngelAutoCameraScreenState extends State<AngelAutoCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0, _generation = 0;
  bool _busy = false, _opening = false, _torch = false, _closed = false;
  bool _list = false, _suspended = false, _resumePending = false;
  DateTime _nextScan = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  String? _error;
  bool get _current =>
      mounted && !_closed && widget.contextIsCurrent?.call() != false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_recognize()),
    );
  }

  Future<void> _initialize() async {
    if (_opening || _closed || _suspended) return;
    _opening = true;
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
        if (_cameras.isEmpty) throw StateError('No camera available');
        final rear = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        _cameraIndex = rear < 0 ? 0 : rear;
      }
      await _openCamera();
    } catch (_) {
      if (_current) {
        setState(
          () => _error =
              'Camera unavailable. Check camera permission. Gallery and File are available.',
        );
      }
    } finally {
      _opening = false;
      _resumeIfNeeded();
    }
  }

  void _resumeIfNeeded() {
    if (_resumePending) {
      _resumePending = false;
      if (_current && !_suspended && _camera == null) { unawaited(_initialize()); }
    }
  }

  Future<void> _openCamera() async {
    final generation = ++_generation;
    final prior = _camera;
    _camera = null;
    await prior?.dispose();
    if (!_current || _suspended) return;
    final next = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await next.initialize();
      if (!_current || _suspended || generation != _generation) {
        await next.dispose();
        return;
      }
      _camera = next;
      _torch = false;
      _nextScan = DateTime.now().add(const Duration(seconds: 3));
      setState(() => _error = null);
    } catch (_) {
      await next.dispose();
      rethrow;
    }
  }

  Future<void> _deliver(Map<String, dynamic> result) async {
    if (!_current) return;
    final items = result['items'] as List? ?? [];
    if (items.isEmpty) return;
    final document =
        widget.api.inventoryMode &&
        (result['type'] == 'document' || items.length > 1);
    result['source_label'] ??= document
        ? (result['document_kind'] == 'receipt'
              ? 'Receipt scanned by Angel'
              : 'Product list scanned by Angel')
        : 'Product scanned by Angel';
    await widget.onRecognized(result, !document);
    _nextScan = DateTime.now().add(const Duration(seconds: 9));
  }

  Future<void> _recognize() async {
    final controller = _camera;
    if (!_current ||
        _busy ||
        _opening ||
        _suspended ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        DateTime.now().isBefore(_nextScan)) {
      return;
    }
    _busy = true;
    _nextScan = DateTime.now().add(const Duration(seconds: 9));
    try {
      final generation = _generation;
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      if (!_current || generation != _generation) return;
      final result = await widget.api.recognize(
        bytes,
        document: _list && widget.api.inventoryMode,
        autoDetect: !_list && widget.api.inventoryMode,
      );
      if (generation == _generation) await _deliver(result);
    } catch (_) {
      // Blurry frames and transient provider failures do not interrupt the preview.
    } finally {
      _busy = false;
    }
  }

  Future<void> _pick({required bool gallery}) async {
    if (_busy || !_current) return;
    _busy = true;
    try {
      if (gallery) {
        final file = await picker.ImagePicker().pickImage(
          source: picker.ImageSource.gallery,
          maxWidth: 2400,
          maxHeight: 3200,
          imageQuality: 88,
          requestFullMetadata: false,
        );
        if (file == null || !_current) return;
        final result = await widget.api.recognize(
          await file.readAsBytes(),
          document: _list && widget.api.inventoryMode,
          autoDetect: !_list && widget.api.inventoryMode,
        );
        await _deliver(result);
      } else {
        final file = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(
              label: widget.api.inventoryMode
                  ? 'Product image, PDF, CSV or Excel'
                  : 'Product image',
              extensions: [
                'jpg',
                'jpeg',
                'png',
                'webp',
                if (widget.api.inventoryMode) ...['pdf', 'csv', 'xlsx'],
              ],
              uniformTypeIdentifiers: [
                'public.image',
                if (widget.api.inventoryMode) ...[
                  'com.adobe.pdf',
                  'public.comma-separated-values-text',
                  'org.openxmlformats.spreadsheetml.sheet',
                ],
              ],
            ),
          ],
        );
        if (file == null || !_current) return;
        if (await file.length() > 20000000) {
          throw StateError('Choose a file smaller than 20 MB.');
        }
        final bytes = await file.readAsBytes();
        final extension = file.name.toLowerCase().split('.').last;
        final result = ['csv', 'xlsx'].contains(extension)
            ? await AngelDocumentReader.readSpreadsheet(
                widget.api,
                bytes,
                file.name,
              )
            : extension == 'pdf'
            ? await AngelDocumentReader.readPdf(
                widget.api,
                bytes,
                contextIsCurrent: () => _current,
              )
            : await widget.api.recognize(
                bytes,
                document: _list && widget.api.inventoryMode,
                autoDetect: !_list && widget.api.inventoryMode,
              );
        result['source_name'] = file.name;
        await _deliver(result);
      }
    } catch (error) {
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Unable to read this file. Try a valid, unencrypted document.',
            ),
          ),
        );
      }
    } finally {
      _busy = false;
      _nextScan = DateTime.now().add(const Duration(seconds: 9));
    }
  }

  Future<void> _flip() async {
    if (_busy || _opening || _cameras.length < 2) return;
    _opening = true;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _openCamera();
    } catch (_) {
      if (_current) setState(() => _error = 'Unable to switch camera.');
    } finally {
      _opening = false;
      _resumeIfNeeded();
    }
  }

  Future<void> _toggleLight() async {
    final camera = _camera;
    if (_opening || camera == null) return;
    try {
      await camera.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (_current && identical(camera, _camera)) {
        setState(() => _torch = !_torch);
      }
    } catch (_) {
      /* Torch may be unavailable on this lens. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _suspended = state != AppLifecycleState.resumed;
    if (!_suspended) {
      if (_camera == null) {
        if (_opening) {
          _resumePending = true;
        } else {
          unawaited(_initialize());
        }
      }
    } else {
      ++_generation;
      final old = _camera;
      _camera = null;
      unawaited(old?.dispose());
    }
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Widget _glass(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xB314213D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: child,
      ),
    ),
  );
  Widget _control(IconData icon, String label, VoidCallback action) => Expanded(
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: action,
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              SizedBox(
                height: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            ClipRect(
              child: LayoutBuilder(
                builder: (context, bounds) => FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: bounds.maxWidth,
                    height:
                        bounds.maxWidth /
                        (MediaQuery.orientationOf(context) ==
                                Orientation.portrait
                            ? 1 / camera.value.aspectRatio
                            : camera.value.aspectRatio),
                    child: CameraPreview(camera),
                  ),
                ),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _glass(
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: Text(
                              'Angel Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (widget.api.inventoryMode)
                        Flexible(
                          child: _glass(
                            Tooltip(
                              message: 'Receipt / Product List',
                              child: InkWell(
                                onTap: () {
                                  if (!_busy) setState(() => _list = !_list);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _list
                                            ? Icons.receipt_long
                                            : Icons.list_alt,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _list
                                              ? 'List scan'
                                              : 'Receipt / List',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: _glass(
                      Row(
                        children: [
                          _control(
                            _torch
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            'Flash',
                            _toggleLight,
                          ),
                          _control(
                            Icons.flip_camera_ios_outlined,
                            'Flip',
                            _flip,
                          ),
                          _control(
                            Icons.photo_outlined,
                            'Gallery',
                            () => _pick(gallery: true),
                          ),
                          _control(
                            Icons.upload_file_outlined,
                            'File',
                            () => _pick(gallery: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
