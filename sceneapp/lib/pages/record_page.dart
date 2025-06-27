import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'dart:io';

class RecordingPage extends StatefulWidget {
  final String extractedText;
  final List<CameraDescription> cameras;

  const RecordingPage({
    super.key,
    required this.extractedText,
    required this.cameras,
  });

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  CameraController? _controller;
  bool _isRecording = false;
  String _cameraMessage = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _cameraMessage = 'No camera found');
      return;
    }

    final frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.max,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _cameraMessage = 'Camera error: $e');
    }
  }

  Future<void> _recordVideo() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      try {
        final XFile file = await _controller!.stopVideoRecording();
        setState(() => _isRecording = false);

        String videoPath = file.path;
        if (videoPath.endsWith('.temp')) {
          final newPath = videoPath.replaceAll('.temp', '.mp4');
          await File(videoPath).rename(newPath);
          videoPath = newPath;
        }

        final bool? success = await GallerySaver.saveVideo(videoPath);
        setState(() => _cameraMessage =
            success == true ? '✅ Saved to gallery!' : '❌ Save failed');
      } catch (e) {
        setState(() => _cameraMessage = 'Error: $e');
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
          _cameraMessage = '🔴 Recording...';
        });
      } catch (e) {
        setState(() => _cameraMessage = 'Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Camera + back button in Stack
            Stack(
              children: [
                Center(
                  child: _controller == null || !_controller!.value.isInitialized
                      ? const SizedBox(
                          height: 350,
                          child: Center(child: CircularProgressIndicator()))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 375,
                            child: AspectRatio(
                              aspectRatio: 0.78,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Record Button
            GestureDetector(
              onTap: _recordVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red.shade600 : Colors.black,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRecording ? Icons.stop : Icons.videocam,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isRecording ? 'Stop Recording' : 'Record Video',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            // Message (camera or save status)
            if (_cameraMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _cameraMessage,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 5),

            // Extracted Script Section
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Script',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.extractedText,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
