import 'package:app/main.dart';
import 'package:app/register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/strings.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _credentialsError;
  bool _obscurePassword = true;


  bool isValidEmail(String email) {
    final emailRegEx = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegEx.hasMatch(email);
  }

  void validateEmail(String value) {
    setState(() {
      if (value.isEmpty || isValidEmail(value)) {
        _emailError = null;
      } else {
        _emailError = AppStrings.invalidEmail;
      }
      _credentialsError = null;
    });
  }

  void onPasswordChanged(String value) {
    setState(() {
      _credentialsError = null;
    });
  }

  Future<void> login() async {
    if (_isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!isValidEmail(email)) {
      setState(() {
        _emailError = AppStrings.invalidEmail;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.loginSuccess)));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _credentialsError = AppStrings.invalidCredentials;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _credentialsError = AppStrings.invalidCredentials;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.loginButton,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF383838),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 8.0,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: AppStrings.emailLabel,
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color(0xFF383838),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          errorText: _emailError ?? _credentialsError,
                        ),
                        onChanged: validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: AppStrings.passwordLabel,
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF383838),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF383838),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          errorText: _credentialsError,
                        ),
                        onChanged: onPasswordChanged,
                      ),

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF383838),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text(
                                  AppStrings.loginButton,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                    );
                  },
                  child: Text(
                    AppStrings.noAccount,
                    style: const TextStyle(color: Color(0xFF383838)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
