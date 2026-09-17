import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../services/i_auth_service.dart';
import '../utils/adaptive_logo.dart';
import '../widgets/jot_ui.dart';
import 'terms_screen.dart';
import 'support_screen.dart';

/// Login screen with email/password authentication via Supabase
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSignUp = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final authService = Provider.of<IAuthService>(context, listen: false);
      final result = await authService.signInWithGmail();
      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pushReplacementNamed('/notes');
      } else {
        setState(() { _errorMessage = result.errorMessage; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'Google Sign-In failed'; _isLoading = false; });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<IAuthService>(context, listen: false);
      
      final result = _isSignUp
          ? await authService.signUpWithEmail(
              _emailController.text.trim(),
              _passwordController.text,
              displayName: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : null,
            )
          : await authService.signInWithEmail(
              _emailController.text.trim(),
              _passwordController.text,
            );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pushReplacementNamed('/notes');
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Authentication failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: JotGradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative background elements
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App logo and Title
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: JotUI.premiumShadow(),
                            ),
                            child: Image.asset(
                              adaptiveLogoPath(context),
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.note_alt_rounded, size: 60, color: theme.colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Jot?',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your thoughts, captured elegantly.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 60),
                        
                        // Login Card
                        JotUI.glassContainer(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isSignUp ? 'Create Account' : 'Welcome Back',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isSignUp
                                      ? 'Sign up to start syncing your notes.'
                                      : 'Sign in to sync your notes across all your devices.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(height: 32),
                                
                                // Name field (sign up only)
                                if (_isSignUp) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    style: TextStyle(color: theme.colorScheme.onSurface),
                                    decoration: const InputDecoration(
                                      labelText: 'Display Name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                
                                // Email field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
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
                                
                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(Icons.lock_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (_isSignUp && value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                
                                if (_isLoading)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                    ),
                                    child: Text(
                                      _isSignUp ? 'Create Account' : 'Sign In',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                
                                const SizedBox(height: 16),
                                
                                // Divider
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text('or', style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontSize: 13,
                                      )),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Google Sign-In button
                                OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: BorderSide(color: theme.colorScheme.outline),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                                  label: const Text('Continue with Google',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Toggle sign in/up
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Text(
                                    _isSignUp
                                        ? 'Already have an account? Sign In'
                                        : "Don't have an account? Sign Up",
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 12),
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const TermsScreen())),
                              ),
                              const TextSpan(text: '  •  '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                              ),
                              const TextSpan(text: '  •  '),
                              TextSpan(
                                text: 'Support',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const SupportScreen())),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
