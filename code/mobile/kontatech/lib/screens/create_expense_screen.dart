import 'package:flutter/material.dart';

class CreateExpenseScreen extends StatelessWidget {
  static const routeName = '/create-expense';
  const CreateExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Endpoint: POST /despesas/
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Despesa')),
      body: const Center(child: Text('Formulário criar despesa -> POST /despesas/')),
    );
  }
}