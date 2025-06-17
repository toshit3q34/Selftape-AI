import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../components/text_field.dart';
import '../components/button.dart';
import '../components/square_tile.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // controllers for text field
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    // sign user in button
    void signuserin() async {
      // show circular progress bar
      showDialog(context: context, builder: (context){
        return const Center(child:CircularProgressIndicator(color: Colors.black,));
      },);

      // login function
      try{
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text
        );
      } on FirebaseAuthException catch(e){
        if(e.code == 'user-not-found'){
          // ignore: avoid_print
          debugPrint("No user found for that email!");
        }
        else if(e.code == 'wrong-password'){
          // ignore: avoid_print
          debugPrint("The entered password is incorrect!");
        }
      }

      
      // pop the bar
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // logo
              Icon(Icons.lock, size: 100),

              SizedBox(height: 10),

              //greeting
              Text(
                'Welcome back you\'ve been missed!',
                style: TextStyle(color: Colors.grey[800], fontSize: 16),
              ),

              SizedBox(height: 20),

              // email textfield
              MyTextField(
                controller: emailController,
                hintText: 'Enter Email',
                obscureText: false,
              ),
              SizedBox(height: 10),
              // password textfield
              MyTextField(
                controller: passwordController,
                hintText: 'Enter Password',
                obscureText: true,
              ),

              SizedBox(height: 10),

              // Forgot password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),

              // Sign In button
              MyButton(onTap: signuserin,),

              SizedBox(height: 30),

              // Divider for alternate options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        thickness: 0.5,
                        color : Colors.grey[400],
                      ),
                    ),
                    Text("  or continue with  "),
                    Expanded(
                      child: Divider(
                        thickness: 0.5,
                        color : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // google button
                SquareTile(imagePath: 'lib/images/google.png'),

                const SizedBox(width: 70),

                // apple button
                SquareTile(imagePath: 'lib/images/apple.png'),
              ],)
            ],
          ),
        ),
      ),
    );
  }
}
