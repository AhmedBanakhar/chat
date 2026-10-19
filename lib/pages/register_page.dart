import 'package:chat/pages/home_page.dart';
import 'package:chat/pages/login_page.dart';
import 'package:chat/widgets/custom_button.dart';
import 'package:chat/widgets/custom_text_field.dart';
import 'package:chat/widgets/sign_up_prompt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  static const String routeName = 'register';

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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

  String? _validateConfirmPassword(String? value) {
    final requiredError = _validateRequired(value);
    if (requiredError != null) return requiredError;

    if (value!.trim() != _passwordController.text.trim()) {
      return 'كلمتا المرور غير متطابقتين';
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
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getAuthErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'email-already-in-use':
        return 'هذا البريد مستخدم بالفعل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جدًا';
      case 'operation-not-allowed':
        return 'تسجيل البريد الإلكتروني غير مفعّل في Firebase';
      default:
        return 'حدث خطأ أثناء إنشاء الحساب';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لم يتم إنشاء المستخدم')));
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'phone': _phoneController.text.trim(),
        'name': user.email?.split('@').first ?? 'مستخدم',
        'bio': 'مرحبًا! أنا أستخدم Scholar Chat',
        'photoUrl': '',
        'biometricEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح')));
      Navigator.pushReplacementNamed(context, HomePage.routeName);
    } on FirebaseAuthException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_getAuthErrorMessage(exception))));
    } on FirebaseException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ بيانات الحساب: ${exception.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حدث خطأ، حاول مرة أخرى')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _brandHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 62),
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
            top: -45,
            right: -35,
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
            bottom: -58,
            left: -38,
            child: Container(
              width: 175,
              height: 175,
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
                  fontFamily: 'Pacifico',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'انضم إلى مجتمعك وابدأ التواصل',
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

  Widget _registerCard() {
    return Transform.translate(
      offset: const Offset(0, -38),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
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
                'أنشئ حسابك',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Color(0xFF16152E),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'أكمل بياناتك وابدأ محادثاتك الآن',
                textAlign: TextAlign.right,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 21),
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _phoneController,
                labelText: 'Phone Number',
                keyboardType: TextInputType.phone,
                validator: _validateRequired,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                obscureText: true,
                validator: _validateRequired,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password',
                obscureText: true,
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 18),
              CustomButton(
                text: _isLoading ? 'Loading...' : 'Register',
                onPressed: _isLoading ? () {} : _register,
              ),
              const SizedBox(height: 16),
              SignUpPrompt(
                text: 'Already have an account? ',
                linkText: 'Login',
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    LoginPage.routeName,
                    (route) => false,
                  );
                },
              ),
            ],
          ),
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8F9FF), Color(0xFFEFF3FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SlideTransition(
              position:
                  _offsetAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
              child: Column(
                children: [
                  _brandHeader(),
                  _registerCard(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      'خطوة واحدة وتبدأ رحلتك',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
