import 'package:flutter/material.dart';

class SignUpPrompt extends StatelessWidget {
  final VoidCallback onTap;
  final String text;
  final String linkText;

  const SignUpPrompt({
    super.key,
    required this.onTap,
    required this.text,
    required this.linkText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        InkWell(
          onTap: onTap,
          child: Text(
            linkText,
            style: const TextStyle(fontSize: 16, color: Colors.blue),
          ),
        ),
      ],
    );
  }
}
