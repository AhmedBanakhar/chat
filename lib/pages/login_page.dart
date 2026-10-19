import 'package:chat/pages/home_page.dart';
import 'package:chat/pages/register_page.dart';
import 'package:chat/widgets/custom_button.dart';
import 'package:chat/widgets/custom_text_field.dart';
import 'package:chat/widgets/sign_up_prompt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const String routeName = 'login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AnimationController? _controller;
  Animation<Offset>? _offsetAnimation;
  bool _isLoading = false;

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _validateRequired(value);
    if (requiredError != null) return requiredError;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value!.trim())) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
        );
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getAuthErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد';
      case 'wrong-password':
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      case 'too-many-requests':
        return 'تمت محاولات كثيرة، حاول لاحقًا';
      default:
        return 'حدث خطأ أثناء تسجيل الدخول';
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول بنجاح')));
      Navigator.pushReplacementNamed(context, HomePage.routeName);
    } on FirebaseAuthException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_getAuthErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _brandHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16152E), Color(0xFF3C2E78), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(42)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -48,
            right: -32,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -55,
            left: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFF3FA1FF).withOpacity(0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Image.asset(
                  'images/icons8-chat-100.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Scholar Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  fontFamily: 'Pacifico',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تواصل، شارك، وابقَ قريبًا',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loginCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 38, 18, 24),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16152E).withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'مرحبًا بعودتك',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Color(0xFF16152E),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'سجّل الدخول للوصول إلى محادثاتك',
              textAlign: TextAlign.right,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 22),
            CustomTextField(
              controller: _emailController,
              labelText: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 13),
            CustomTextField(
              controller: _passwordController,
              labelText: 'Password',
              obscureText: true,
              validator: _validateRequired,
            ),
            const SizedBox(height: 18),
            CustomButton(
              text: _isLoading ? 'Loading...' : 'Login',
              onPressed: _isLoading ? () {} : _signIn,
            ),
            const SizedBox(height: 16),
            SignUpPrompt(
              text: 'Don\'t have an account? ',
              linkText: 'Register',
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RegisterPage.routeName,
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF5F7FB),
        body: SafeArea(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8F9FF), Color(0xFFEFF3FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: SlideTransition(
                      position:
                          _offsetAnimation ??
                          const AlwaysStoppedAnimation(Offset.zero),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _brandHeader(),
                          _loginCard(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(
                              'آمن، بسيط، ومصمم لتواصلك',
                              style: TextStyle(
                                color: const Color(
                                  0xFF94A3B8,
                                ).withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
