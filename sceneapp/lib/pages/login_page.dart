import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../components/text_field.dart';
import '../components/button.dart';
import '../components/square_tile.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFFFA69E);
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    void signuserin() async {
      showDialog(
        context: context,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.black),
          );
        },
      );

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          debugPrint("No user found for that email!");
        } else if (e.code == 'wrong-password') {
          debugPrint("The entered password is incorrect!");
        }
      }

      Navigator.pop(context);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Optional: Background circle design
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.3),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -60,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.3),
                ),
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          const Icon(Icons.lock_outline, size: 80, color: Colors.black87),
                          const SizedBox(height: 10),
                          Text(
                            'SelfTape-AI',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Welcome back, you’ve been missed!',
                            style: TextStyle(color: Colors.grey[800], fontSize: 16),
                          ),
                          const SizedBox(height: 30),

                          MyTextField(
                            controller: emailController,
                            hintText: 'Enter Email',
                            obscureText: false,
                          ),
                          const SizedBox(height: 10),

                          MyTextField(
                            controller: passwordController,
                            hintText: 'Enter Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),

                          MyButton(
                            onTap: signuserin,
                            color: primaryColor,
                          ),
                          const SizedBox(height: 40),

                          Row(
                            children: [
                              Expanded(
                                child: Divider(thickness: 0.5, color: Colors.grey[400]),
                              ),
                              const Text("  or continue with  "),
                              Expanded(
                                child: Divider(thickness: 0.5, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SquareTile(imagePath: 'lib/images/google.png'),
                              const SizedBox(width: 70),
                              SquareTile(imagePath: 'lib/images/apple.png'),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}