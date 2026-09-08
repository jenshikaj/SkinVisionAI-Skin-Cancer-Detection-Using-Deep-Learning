import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_notification.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // 0 = Sign In, 1 = Sign Up
  int _selectedTab = 0;
  late AnimationController _slideCtrl;
  late Animation<double> _slideAnim;

  bool _loading = false;

  // Sign In
  final _signInKey = GlobalKey<FormState>();
  final _siEmail = TextEditingController();
  final _siPass = TextEditingController();
  bool _siPassVisible = false;

  // Sign Up
  final _signUpKey = GlobalKey<FormState>();
  final _suName = TextEditingController();
  final _suEmail = TextEditingController();
  final _suPass = TextEditingController();
  final _suConfirm = TextEditingController();
  bool _suPassVisible = false;
  bool _suConfirmVisible = false;

  // PageController for content
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pageCtrl.dispose();
    _siEmail.dispose();
    _siPass.dispose();
    _suName.dispose();
    _suEmail.dispose();
    _suPass.dispose();
    _suConfirm.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (index == 1) {
      _slideCtrl.forward();
    } else {
      _slideCtrl.reverse();
    }
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _saveUserToFirestore({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
    bool mergeIfExists = false,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: mergeIfExists));
  }

  Future<void> _signIn() async {
    if (!_signInKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _siEmail.text.trim(),
        password: _siPass.text,
      );
      if (!mounted) return;
      AppNotification.success(context, 'Welcome back! 👋');
      await Future.delayed(const Duration(milliseconds: 800));
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppNotification.error(context, _authError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_signUpKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _suEmail.text.trim(),
        password: _suPass.text,
      );
      await cred.user?.updateDisplayName(_suName.text.trim());
      await _saveUserToFirestore(
        uid: cred.user!.uid,
        name: _suName.text.trim(),
        email: _suEmail.text.trim(),
        photoUrl: '',
      );
      if (!mounted) return;
      AppNotification.success(context, 'Account created! Welcome');
      await Future.delayed(const Duration(milliseconds: 800));
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppNotification.error(context, _authError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) {
        setState(() => _loading = false);
        return;
      }
      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      await _saveUserToFirestore(
        uid: result.user!.uid,
        name: result.user?.displayName ?? '',
        email: result.user?.email ?? '',
        photoUrl: result.user?.photoURL ?? '',
        mergeIfExists: true,
      );
      if (!mounted) return;
      AppNotification.success(context, 'Signed in with Google');
      await Future.delayed(const Duration(milliseconds: 800));
      _goHome();
    } catch (_) {
      if (!mounted) return;
      AppNotification.error(context, 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          ),

          // Decorative circle
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Logo
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/app_icon/splash.png',
                      width: 60, height: 60),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SkinVision AI',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dermatology insights at your fingertips',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 28),

                // White card sheet
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ── Custom sliding toggle ──
                        _buildSlidingToggle(),

                        const SizedBox(height: 4),

                        // ── PageView content ──
                        Expanded(
                          child: PageView(
                            controller: _pageCtrl,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildSignIn(),
                              _buildSignUp(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black38,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SLIDING TOGGLE
  // ─────────────────────────────────────────────
  Widget _buildSlidingToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Animated sliding pill
              AnimatedBuilder(
                animation: _slideAnim,
                builder: (_, __) {
                  return Positioned(
                    left: _slideAnim.value * halfWidth,
                    top: 4,
                    bottom: 4,
                    width: halfWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Tap targets (two halves)
              Row(
                children: [
                  // Sign In half
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(0),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 0
                                ? Colors.white
                                : AppTheme.textMid,
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                    ),
                  ),

                  // Sign Up half
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(1),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 1
                                ? Colors.white
                                : AppTheme.textMid,
                          ),
                          child: const Text('Sign Up'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SIGN IN FORM
  // ─────────────────────────────────────────────
  Widget _buildSignIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: _signInKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome back',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text('Sign in to your account',
                style:
                    TextStyle(fontFamily: 'Nunito', color: AppTheme.textMid)),
            const SizedBox(height: 24),
            _label('Email Address'),
            TextFormField(
              controller: _siEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v))
                  return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Password'),
            TextFormField(
              controller: _siPass,
              obscureText: !_siPassVisible,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.primary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _siPassVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.textLight,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _siPassVisible = !_siPassVisible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'At least 6 characters required';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: const Text('Sign In')),
            const SizedBox(height: 16),
            _orDivider(),
            const SizedBox(height: 16),
            _googleButton(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SIGN UP FORM
  // ─────────────────────────────────────────────
  Widget _buildSignUp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: _signUpKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create account',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text('Start your skin health journey',
                style:
                    TextStyle(fontFamily: 'Nunito', color: AppTheme.textMid)),
            const SizedBox(height: 24),
            _label('Full Name'),
            TextFormField(
              controller: _suName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'John Doe',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Email Address'),
            TextFormField(
              controller: _suEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v))
                  return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Password'),
            TextFormField(
              controller: _suPass,
              obscureText: !_suPassVisible,
              decoration: InputDecoration(
                hintText: 'Min. 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.primary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _suPassVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.textLight,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _suPassVisible = !_suPassVisible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8)
                  return 'Password must be at least 8 characters';
                if (!RegExp(r'[A-Z]').hasMatch(v))
                  return 'Include at least one uppercase letter';
                if (!RegExp(r'[0-9]').hasMatch(v))
                  return 'Include at least one number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Confirm Password'),
            TextFormField(
              controller: _suConfirm,
              obscureText: !_suConfirmVisible,
              decoration: InputDecoration(
                hintText: 'Re-enter password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.primary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _suConfirmVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.textLight,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _suConfirmVisible = !_suConfirmVisible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm password';
                if (v != _suPass.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child: const Text('Create Account')),
            const SizedBox(height: 16),
            _orDivider(),
            const SizedBox(height: 16),
            _googleButton(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Colors.grey.shade400)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade200),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Image.network(
          'https://developers.google.com/identity/images/g-logo.png',
          width: 20,
          height: 20,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.g_mobiledata, color: AppTheme.primary),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}
