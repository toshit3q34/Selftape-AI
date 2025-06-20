import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:sceneapp/pages/record_page.dart';
import 'package:sceneapp/ip_address.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? fileName;
  String? filePath;
  List<CameraDescription>? cameras;
  bool _loadingCameras = true;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      final cams = await availableCameras();
      setState(() {
        cameras = cams;
        _loadingCameras = false;
      });
    } catch (e) {
      setState(() {
        cameras = [];
        _loadingCameras = false;
      });
      print('Camera initialization error: $e');
    }
  }

  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  Future<void> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        fileName = file.name;
        filePath = file.path;
      });
    } else {
      print('No PDF selected');
    }
  }

  Future<void> convertToText() async {
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a PDF first.')),
      );
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://${Config.IP_ADDRESS}:8000/upload-pdf/'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath!));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final text = responseBody.contains('"text"')
            ? responseBody.split('"text":"')[1].split('"').first.replaceAll('\\n', '\n')
            : '';

        // Navigate to RecordingPage if cameras are available
        if (cameras != null && cameras!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordingPage(
                extractedText: text,
                cameras: cameras!,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera initialization failed. Please try again.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to backend.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCameras) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: signUserOut,
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description, size: 100),

                const SizedBox(height: 10),

                Text(
                  'Hello, ${user?.email ?? 'User'} 👋',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: pickPdfFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                if (fileName != null)
                  Text(
                    '📄 $fileName',
                    style: TextStyle(color: Colors.grey[700]),
                  ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: convertToText,
                  child: const Text('Convert to Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
