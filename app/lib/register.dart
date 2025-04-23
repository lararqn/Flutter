import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/strings.dart';
import 'package:app/login.dart';
import 'package:image_picker/image_picker.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  DateTime? selectedDate;
  XFile? _profileImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _firstNameError;
  String? _lastNameError;
  String? _dateError;

  bool isValidEmail(String email) {
    final emailRegEx = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegEx.hasMatch(email);
  }

  bool isValidPassword(String password) {
    final passwordRegEx = RegExp(
      r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*?])[A-Za-z\d!@#$%^&*?]{8,}$',
    );
    return passwordRegEx.hasMatch(password);
  }

  void validateEmail(String value) {
    setState(() {
      if (value.isEmpty || isValidEmail(value)) {
        _emailError = null;
      } else {
        _emailError = AppStrings.invalidEmail;
      }
    });
  }

  void validatePassword(String value) {
    setState(() {
      if (value.isEmpty || isValidPassword(value)) {
        _passwordError = null;
      } else {
        _passwordError = AppStrings.passwordInvalid;
      }
    });
  }

  void validateFirstName(String value) {
    setState(() {
      if (value.isEmpty) {
        _firstNameError = 'Voornaam is verplicht';
      } else {
        _firstNameError = null;
      }
    });
  }

  void validateLastName(String value) {
    setState(() {
      if (value.isEmpty) {
        _lastNameError = 'Achternaam is verplicht';
      } else {
        _lastNameError = null;
      }
    });
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateError = null;
      });
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij kiezen profielfoto: $e')),
      );
    }
  }

  Future<String?> convertImageToBase64(String userId) async {
    if (_profileImage == null) return null;

    try {
      final bytes = await _profileImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij converteren profielfoto: $e')),
      );
      return null;
    }
  }

  Future<void> register() async {
    if (_isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    validateEmail(email);
    validatePassword(password);
    validateFirstName(firstName);
    validateLastName(lastName);

    if (selectedDate == null) {
      setState(() {
        _dateError = 'Geboortedatum is verplicht';
      });
    }

    if (_emailError != null ||
        _passwordError != null ||
        _firstNameError != null ||
        _lastNameError != null ||
        selectedDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user != null) {
        String? photoBase64 = await convertImageToBase64(user.uid);

        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'birthDate': selectedDate!.toIso8601String(),
          'email': email,
          'photoBase64': photoBase64, 
          'createdAt': Timestamp.now(),
        });

        await user.updateDisplayName('$firstName $lastName');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.registerSuccess)),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = AppStrings.emailInUse;
          break;
        case 'invalid-email':
          errorMessage = AppStrings.invalidEmail;
          break;
        case 'weak-password':
          errorMessage = AppStrings.passwordWeak;
          break;
        default:
          errorMessage = AppStrings.registerError;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.registerError} $e')),
        );
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
                AppStrings.registerTitle,
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
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Voornaam',
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF383838),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          errorText: _firstNameError,
                        ),
                        onChanged: validateFirstName,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Achternaam',
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF383838),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          errorText: _lastNameError,
                        ),
                        onChanged: validateLastName,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Geboortedatum',
                            prefixIcon: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF383838),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            errorText: _dateError,
                          ),
                          child: Text(
                            selectedDate == null
                                ? 'Selecteer datum'
                                : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                            style: TextStyle(
                              color: selectedDate == null ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _profileImage == null
                                  ? 'Geen profielfoto geselecteerd'
                                  : 'Profielfoto geselecteerd',
                              style: TextStyle(
                                color: _profileImage == null ? Colors.grey : Colors.black,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: pickImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF383838),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Kies Profielfoto',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                          errorText: _emailError,
                        ),
                        onChanged: validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: AppStrings.passwordLabel,
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF383838),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          errorText: _passwordError,
                        ),
                        onChanged: validatePassword,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : register,
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
                                AppStrings.registerButton,
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
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: Text(
                    AppStrings.alreadyHaveAccount,
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

extension XFileExtension on XFile {
  Future<File> toFile() async {
    return File(path);
  }
}