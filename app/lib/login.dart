import 'dart:convert';
import 'package:app/main.dart';
import 'package:app/register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

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
      setState(() {
        _currentUser = userCredential.user;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.loginSuccess)),
        );
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
              if (_currentUser != null)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('Users')
                      .doc(_currentUser!.uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      print('Error fetching user document: ${snapshot.error}');
                      return const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.error, size: 50),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      print('User document does not exist for UID: ${_currentUser!.uid}');
                      return const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.person, size: 50),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final photoBase64 = data['photoBase64'] as String?;

                    print('Fetched photoBase64: $photoBase64');

                    if (photoBase64 != null && photoBase64.startsWith('data:image/jpeg;base64,')) {
                      try {
                        final base64String = photoBase64.split(',')[1];
                        final imageBytes = base64Decode(base64String);
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: MemoryImage(imageBytes),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Welcome, ${_currentUser!.displayName ?? 'User'}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                setState(() {
                                  _currentUser = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF383838),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: const Text(
                                'Log Out',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      } catch (e) {
                        print('Error decoding base64 string: $e');
                        return const CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.broken_image, size: 50),
                        );
                      }
                    }

                    print('No valid photoBase64 found');
                    return const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    );
                  },
                )
              else
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
                          child: _isLoading
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