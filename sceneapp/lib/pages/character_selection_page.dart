import 'package:flutter/material.dart';
import 'package:sceneapp/pages/record_page.dart';
import 'package:camera/camera.dart';

class CharacterSelectionPage extends StatefulWidget {
  final String extractedText;
  final List<String> characters;
  final List<CameraDescription> cameras;

  const CharacterSelectionPage({
    super.key,
    required this.extractedText,
    required this.characters,
    required this.cameras,
  });

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFFFFA69E);
  Map<String, String> characterMap = {};
  late AnimationController _rippleController;
  late Animation<double> _ripple1, _ripple2;

  @override
  void initState() {
    super.initState();

    // Setup characters
    characterMap = {for (var c in widget.characters) c: "Me"};

    // Setup ripple animation
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _ripple1 = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    _ripple2 = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ripple background
          Positioned(
            top: -60,
            left: -80,
            child: AnimatedBuilder(
              animation: _ripple1,
              builder: (context, child) => Transform.scale(
                scale: _ripple1.value,
                child: _buildRipple(250, 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -70,
            child: AnimatedBuilder(
              animation: _ripple2,
              builder: (context, child) => Transform.scale(
                scale: _ripple2.value,
                child: _buildRipple(200, 0.3),
              ),
            ),
          ),

          // Custom AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                top: 50,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SelfTape-AI',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select Characters!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 120.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.characters.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final character = widget.characters[index];
                        return ListTile(
                          title: Text(character),
                          trailing: ToggleButtons(
                            isSelected: [
                              characterMap[character] == "Me",
                              characterMap[character] == "AI",
                            ],
                            onPressed: (int i) {
                              setState(() {
                                characterMap[character] = i == 0 ? "Me" : "AI";
                              });
                            },
                            children: const [Text("Me"), Text("AI")],
                            borderRadius: BorderRadius.circular(10),
                            selectedColor: Colors.white,
                            fillColor: primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecordingPage(
                              extractedText: widget.extractedText,
                              cameras: widget.cameras,
                              // You can pass characterMap if needed
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Continue to Record"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
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

  // Ripple widget
  Widget _buildRipple(double size, double opacity) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor.withOpacity(opacity),
      ),
    );
  }
}
