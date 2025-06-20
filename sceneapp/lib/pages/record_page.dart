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

    // Use front camera if available
    final frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
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
        // Rename .temp files
        if (videoPath.endsWith('.temp')) {
          final newPath = videoPath.replaceAll('.temp', '.mp4');
          await File(videoPath).rename(newPath);
          videoPath = newPath;
        }

        final bool? success = await GallerySaver.saveVideo(videoPath);
        setState(() => _cameraMessage = success == true
            ? 'Video saved to gallery!'
            : 'Failed to save video');
      } catch (e) {
        setState(() => _cameraMessage = 'Error: $e');
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
          _cameraMessage = 'Recording...';
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
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera Preview Section
            Expanded(
              flex: 3,
              child: _controller == null || !_controller!.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
            ),
            
            // Recording Controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
                label: Text(_isRecording ? 'Stop Recording' : 'Record Video'),
                onPressed: _recordVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ),
            
            if (_cameraMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(_cameraMessage, textAlign: TextAlign.center),
              ),
            
            // Extracted Text Section
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Script:',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.extractedText,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}