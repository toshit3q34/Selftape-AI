import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? fileName;
  String? filePath;
  String? extractedText;

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
        extractedText = null;
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
      Uri.parse('http://127.0.0.1:8000/upload-pdf/'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath!));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final text = responseBody.contains('"text"')
            ? responseBody.split('"text":"')[1].split('"').first.replaceAll('\\n', '\n')
            : '';

        final lines = text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .take(5)
            .toList();

        setState(() {
          extractedText = lines.join('\n');
        });
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

                const SizedBox(height: 20),

                if (extractedText != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Preview:',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        extractedText!,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
