import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = context.read<AuthProvider>();
    bool success;
    
    if (_isSignUp) {
      success = await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
    
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFD4AF37),
              const Color(0xFF8B4513),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.temple_buddhist,
                          size: 80,
                          color: const Color(0xFFD4AF37),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSignUp ? 'Create Account' : 'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.isLoading) {
                              return const CircularProgressIndicator();
                            }
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    _isSignUp ? 'Sign Up' : 'Sign In',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                            });
                          },
                          child: Text(
                            _isSignUp
                                ? 'Already have an account? Sign In'
                                : 'Don\'t have an account? Sign Up',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            final authProvider = context.read<AuthProvider>();
                            authProvider.setGuestMode();
                            Navigator.of(context).pushReplacementNamed('/home');
                          },
                          child: const Text('Continue as Guest'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
