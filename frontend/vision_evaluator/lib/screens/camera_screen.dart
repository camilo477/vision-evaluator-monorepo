import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  final Function(File?, Uint8List?) onPictureTaken;

  const CameraScreen({super.key, required this.onPictureTaken});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isCameraReady = false;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      _takePhotoWeb();
      return;
    }

    cameras = await availableCameras();
    controller = CameraController(
      cameras!.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;
    setState(() => isCameraReady = true);
  }

  Future<void> _takePhotoWeb() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.camera);

    if (file == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final bytes = await file.readAsBytes();
    widget.onPictureTaken(null, bytes);

    if (mounted) Navigator.pop(context);
  }

  Future<void> takePicture() async {
    if (controller == null || !controller!.value.isInitialized || isCapturing) {
      return;
    }

    setState(() => isCapturing = true);

    try {
      final XFile file = await controller!.takePicture();
      widget.onPictureTaken(File(file.path), null);

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isCameraReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller!)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Captura una imagen',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Ubica bien el objeto o escena dentro del encuadre para obtener una comparación más clara.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: takePicture,
                    child: Container(
                      width: 86,
                      height: 86,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCapturing ? Colors.white54 : Colors.white,
                        ),
                        child: isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.black87,
                                size: 34,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
