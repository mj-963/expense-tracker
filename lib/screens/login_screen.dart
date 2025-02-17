import 'package:expense_tracker/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      // Navigate to Home if successful
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication error')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            );
          }

          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pushReplacementNamed(context, '/home'),
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Optional logo/icon
                          Icon(
                            Icons.account_balance_wallet,
                            size: 64,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Login to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Email Field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an email.';
                              }
                              return null;
                            },
                            onSaved: (value) => _email = value!.trim(),
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password.';
                              }
                              return null;
                            },
                            onSaved: (value) => _password = value!.trim(),
                          ),
                          const SizedBox(height: 24),
                          // Login Button
                          _isLoading
                              ? CircularProgressIndicator(
                                color: AppColors.secondary,
                              )
                              : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    backgroundColor: AppColors.secondary,
                                  ),
                                  onPressed: _login,
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                          const SizedBox(height: 16),
                          // Navigate to Signup
                          TextButton(
                            onPressed:
                                () => Navigator.pushNamed(context, '/signup'),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
