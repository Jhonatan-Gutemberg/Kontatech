import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  static const routeName = '/register';
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Endpoint: POST /auth/register
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar')),
      body: const Center(child: Text('Formulário de registro -> POST /auth/register')),
    );
  }
}