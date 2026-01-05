import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../auth_manager.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthManager().signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SapemoiTheme.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await AuthManager().signInWithApple();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SapemoiTheme.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all fields'),
          backgroundColor: SapemoiTheme.surface,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await AuthManager().signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await AuthManager().signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SapemoiTheme.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SapemoiTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo avec glow
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SapemoiTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: SapemoiTheme.primary.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.checkroom_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Titre avec gradient
                ShaderMask(
                  shaderCallback: (bounds) => SapemoiTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Sapemoi',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Organize your wardrobe',
                  style: TextStyle(
                    fontSize: 16,
                    color: SapemoiTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 48),

                // Email Field
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Password Field
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: SapemoiTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 24),

                // Email Sign In/Up Button
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: CircularProgressIndicator(color: SapemoiTheme.primary),
                  )
                else
                  GestureDetector(
                    onTap: _signInWithEmail,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: SapemoiTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                        boxShadow: [SapemoiTheme.shadowGlow(SapemoiTheme.primary)],
                      ),
                      child: Text(
                        _isSignUp ? 'Sign Up' : 'Sign In',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Toggle Sign In / Sign Up
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                    style: TextStyle(
                      color: SapemoiTheme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                
                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: SapemoiTheme.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: SapemoiTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: SapemoiTheme.border)),
                  ],
                ),
                const SizedBox(height: 32),

                // Google Sign In
                _buildSocialButton(
                  onTap: _isLoading ? null : _signInWithGoogle,
                  icon: Image.asset(
                    'assets/google_logo.png',
                    height: 22,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.g_mobiledata, size: 22, color: Colors.white),
                  ),
                  label: 'Continue with Google',
                ),
                const SizedBox(height: 12),

                // Apple Sign In (iOS only)
                if (Platform.isIOS)
                  _buildSocialButton(
                    onTap: _isLoading ? null : _signInWithApple,
                    icon: const Icon(Icons.apple, size: 22, color: Colors.white),
                    label: 'Continue with Apple',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(color: SapemoiTheme.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: !_isLoading,
        style: TextStyle(color: SapemoiTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: SapemoiTheme.textMuted),
          prefixIcon: Icon(icon, color: SapemoiTheme.textMuted, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          floatingLabelStyle: TextStyle(color: SapemoiTheme.primary),
        ),
        cursorColor: SapemoiTheme.primary,
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onTap,
    required Widget icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: SapemoiTheme.surface,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
          border: Border.all(color: SapemoiTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: SapemoiTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
